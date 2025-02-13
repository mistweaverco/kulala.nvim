local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local FS = require("kulala.utils.fs")
local ENV_PARSER = require("kulala.parser.env")
local DOCUMENT_PARSER = require("kulala.parser.document")
local GRAPHQL_PARSER = require("kulala.parser.graphql")
local PARSER_UTILS = require("kulala.parser.utils")
local STRING_UTILS = require("kulala.utils.string")
local CURL_FORMAT_FILE = FS.get_plugin_path({ "parser", "curl-format.json" })
local StringVariablesParser = require("kulala.parser.string_variables_parser")
local Logger = require("kulala.logger")

local M = {}

M.scripts = {}
M.scripts.javascript = require("kulala.parser.scripts.javascript")

---@class Request
---@field metadata table<{name: string, value: string}> -- Metadata of the request
---@field method string -- The HTTP method of the request
---@field url_raw string -- The raw URL as it appears in the document
---@field url string -- The URL with variables and dynamic variables replaced
---@field headers table<string, string> -- The headers with variables and dynamic variables replaced
---@field headers_display table<string, string> -- The headers with variables and dynamic variables replaced and sanitized
---@field headers_raw table<string, string> -- The headers as they appear in the document
---@field body_raw string|nil -- The raw body as it appears in the document
---@field body_computed string|nil -- The computed body as sent by curl; with variables and dynamic variables replaced
---@field body_display string|nil -- The body with variables and dynamic variables replaced and sanitized
---(e.g. with binary files replaced with a placeholder)
---@field body string|nil -- The body with variables and dynamic variables replaced
---@field environment table<string, string|number> -- The environment- and document-variables
---@field cmd string[] -- The command to execute the request
---@field ft string -- The filetype of the document
---@field http_version string -- The HTTP version of the request
---@field show_icon_line_number number -- The line number to show the icon
---@field scripts Scripts -- The scripts to run before and after the request
---@field redirect_response_body_to_files ResponseBodyToFile[]
---@field body_temp_file string -- The path to the temporary file containing the body

---@type Request
local default_request = {
  metadata = {},
  method = "GET",
  http_version = "",
  url = "",
  url_raw = "",
  headers = {},
  headers_display = {},
  headers_raw = {},
  body = nil,
  body_raw = nil,
  body_computed = nil,
  body_display = nil,
  cmd = {},
  ft = "text",
  environment = {},
  redirect_response_body_to_files = {},
  scripts = {
    pre_request = {
      inline = {},
      files = {},
    },
    post_request = {
      inline = {},
      files = {},
    },
  },
  show_icon_line_number = 1,
  body_temp_file = "",
}

-- Deprecated: use "< path/to/file" in place instead of @file-to-variable
-- extend the document_variables with the variables defined in the request
-- via the # @file-to-variable variable_name file_path metadata syntax
---@param document_variables table|nil
---@param request Request
---@return table
local function append_file_to_variables(document_variables, request)
  document_variables = document_variables or {}

  for _, metadata in ipairs(request.metadata) do
    if metadata.name == "file-to-variable" then
      local variable_name, file_path = unpack(vim.split(metadata.value, " "))
      document_variables[variable_name] = DOCUMENT_PARSER.expand_included_filepath("< " .. file_path)
    end
  end

  return document_variables
end

local function cleanup_request_files()
  FS.delete_file(GLOBALS.HEADERS_FILE)
  FS.delete_file(GLOBALS.BODY_FILE)
  FS.delete_file(GLOBALS.COOKIES_JAR_FILE)
end

local function url_encode(str)
  if CONFIG.get().urlencode == "skipencoded" then
    return STRING_UTILS.url_encode_skipencoded(str)
  else
    return STRING_UTILS.url_encode(str)
  end
end

local function encode_url_params(url)
  local anchor = ""
  local index = url:find("#")
  if index then
    anchor = "#" .. url_encode(url:sub(index + 1))
    url = url:sub(1, index - 1)
  end

  index = url:find("?")
  if not index then
    return url .. anchor
  end

  local query = url:sub(index + 1)
  url = url:sub(1, index - 1)

  local query_parts = {}
  if query then
    query_parts = vim.split(query, "&")
  end

  local query_params = ""
  for _, query_part in ipairs(query_parts) do
    index = query_part:find("=")
    if index then
      query_params = query_params
        .. "&"
        .. url_encode(query_part:sub(1, index - 1))
        .. "="
        .. url_encode(query_part:sub(index + 1))
    else
      query_params = query_params .. "&" .. url_encode(query_part)
    end
  end

  if query_params ~= "" then
    url = url .. "?" .. query_params:sub(2)
  end
  return url .. anchor
end

local function parse_url(url, variables, env, silent)
  url = StringVariablesParser.parse(url, variables, env, silent)
  url = encode_url_params(url)
  return url:gsub('"', "")
end

local function parse_headers(headers, variables, env, silent)
  return vim.iter(headers):fold({}, function(ret, k, v)
    ret[StringVariablesParser.parse(k, variables, env, silent)] = StringVariablesParser.parse(v, variables, env, silent)
    return ret
  end)
end

---Replace the variables in the URL, headers and body
---@param request Request -- The request object
---@param document_variables table -- The variables defined in the document
---@param env table -- The environment variables
---@param silent boolean -- Whether to suppress not found variable warnings
local process_variables = function(request, document_variables, env, silent)
  local params = { document_variables or {}, env or {}, silent }

  request.url = parse_url(request.url_raw, unpack(params))
  request.headers = parse_headers(request.headers, unpack(params))
  request.body = StringVariablesParser.parse(request.body_raw, unpack(params))
  request.body_display = StringVariablesParser.parse(request.body_display, unpack(params))
  request.body_computed = request.body
end

---Save body to a temporary file, including files specified with "< /path" syntax into request body
---NOTE: We are not saving the line endings, except "\r\n" which appear in multipart-form

---@param request_body string
---@return boolean|nil status
---@return string|nil result_path path
local function save_body_with_files(request_body)
  local status = true
  local result_path = FS.get_binary_temp_file("")

  local result = io.open(result_path, "a+b")
  if not result then
    return
  end

  local lines = vim.split(request_body, "\n")

  for _, line in ipairs(lines) do
    -- skip lines that begin with '< [file not found]'
    local path = line:match("^< ([^%[\r\n]+)[\r\n]*$")

    if path then
      if not FS.include_file(result, path) then
        Logger.warn("The file '" .. path .. "' could not be included. Skipping ...")
      end
    else
      line = line:find("\r$") and line .. "\n" or line
      ---@diagnostic disable-next-line: cast-local-type
      status = status and result:write(line)
    end
  end

  status = status and result:close()

  return status, result_path
end

local function set_variables(request, document_variables)
  local env = ENV_PARSER.get_env()

  document_variables = append_file_to_variables(document_variables, request)
  request.environment = vim.tbl_extend("force", env, document_variables)

  -- INFO: if has_pre_request_script:
  -- silently replace the variables in the URL, headers and body, otherwise warn the user
  -- for non existing variables
  local has_pre_request_scripts = #request.scripts.pre_request.inline > 0 or #request.scripts.pre_request.files > 0
  process_variables(request, document_variables, env, has_pre_request_scripts)
end

local function set_headers(request)
  request.headers_display = vim.deepcopy(request.headers)

  -- Merge headers from the $shared environment if it does not exist in the request
  -- this ensures that you can always override the headers in the request
  local default_headers = (DB.find_unique("http_client_env_shared") or {})["$default_headers"]
  vim.iter(default_headers or {}):each(function(name, value)
    name = PARSER_UTILS.get_header(request.headers, name) or name
    request.headers[name] = request.headers[name] or value
  end)
end

local function process_graphql(request)
  local is_graphql = PARSER_UTILS.contains_meta_tag(request, "graphql")
    or PARSER_UTILS.contains_header(request.headers, "x-request-type", "graphql")

  if request.body and #request.body > 0 and is_graphql then
    local gql_json = GRAPHQL_PARSER.get_json(request.body)

    if gql_json then
      local content_type_header_name = PARSER_UTILS.get_header(request.headers, "Content-Type") or "Content-Type"

      request.headers[content_type_header_name] = "application/json"
      request.body_computed = gql_json
    end
  end
end

local function process_pre_request_scripts(request, document_variables)
  if not (#request.scripts.pre_request.inline > 0 or #request.scripts.pre_request.files > 0) then
    return
  end

  -- PERF: We only want to run the scripts if they exist
  -- Also we don't want to re-run the environment replace_variables_in_url_headers_body
  -- if we don't actually have any scripts to run that could have changed the environment

  -- INFO:
  -- This runs a client and request script that can be used to magic things
  -- See: https://www.jetbrains.com/help/idea/http-response-reference.html
  M.scripts.javascript.run("pre_request", request.scripts.pre_request)

  -- INFO: now replace the variables in the URL, headers and body again,
  -- because user scripts could have changed them,
  -- but this time also warn the user if a variable is not found
  set_variables(request, document_variables)
end

local function process_body(request)
  local content_type_header_name, content_type_header_value = PARSER_UTILS.get_header(request.headers, "content-type")

  if content_type_header_name and content_type_header_value and request.body and #request.body_computed > 0 then
    local status, path = save_body_with_files(request.body_computed)

    if status then
      request.body_temp_file = path
      table.insert(request.cmd, "--data-binary")
      table.insert(request.cmd, "@" .. path)
    else
      Logger.error("Failed to create a temporary file for the request body")
    end
  end
end

local function process_auth_headers(request)
  local auth_header_name, auth_header_value = PARSER_UTILS.get_header(request.headers, "authorization")
  if not (auth_header_name and auth_header_value) then
    return
  end

  local authtype = auth_header_value:match("^(%w+)%s+.*")
  if not authtype then
    authtype = auth_header_value:match("^(%w+)%s*$")
  end

  if authtype then
    authtype = authtype:lower()

    if vim.tbl_contains({ "ntlm", "negotiate", "digest", "basic" }, authtype) then
      local match, authuser, authpw = auth_header_value:match("^(%w+)%s+([^%s:]+)%s*[:%s]%s*([^%s]+)%s*$")

      if match or (authtype == "ntlm" or authtype == "negotiate") then
        table.insert(request.cmd, "--" .. authtype)
        table.insert(request.cmd, "-u")
        table.insert(request.cmd, (authuser or "") .. ":" .. (authpw or ""))
        request.headers[auth_header_name] = nil
      end
    elseif authtype == "aws" then
      local key, secret, optional = auth_header_value:match("^%w+%s([^%s]+)%s*([^%s]+)[%s$]+(.*)$")
      local token = optional:match("token:([^%s]+)")
      local region = optional:match("region:([^%s]+)")
      local service = optional:match("service:([^%s]+)")
      local provider = "aws:amz"

      if region then
        provider = provider .. ":" .. region
      end
      if service then
        provider = provider .. ":" .. service
      end

      table.insert(request.cmd, "--aws-sigv4")
      table.insert(request.cmd, provider)
      table.insert(request.cmd, "-u")
      table.insert(request.cmd, key .. ":" .. secret)

      if token then
        table.insert(request.cmd, "-H")
        table.insert(request.cmd, "x-amz-security-token:" .. token)
      end

      request.headers[auth_header_name] = nil
    end
  end
end

local function process_protocol(request)
  local protocol, host, port = request.url:match("^([^:]*)://([^:/]*):([^/]*)")

  if not protocol then
    protocol, host = request.url:match("^([^:]*)://([^:/]*)")
  end

  if protocol ~= "https" then
    return
  end

  local certificate = CONFIG.get().certificates[host .. ":" .. (port or "443")]
  if not certificate then
    certificate = CONFIG.get().certificates[host]
  end

  if not certificate then
    while host ~= "" do
      certificate = CONFIG.get().certificates["*." .. host .. ":" .. (port or "443")]

      if not certificate then
        certificate = CONFIG.get().certificates["*." .. host]
      end
      if certificate then
        break
      end

      host = host:gsub("^[^%.]+%.?", "")
    end
  end

  if certificate then
    if certificate.cert then
      table.insert(request.cmd, "--cert")
      table.insert(request.cmd, certificate.cert)
    end

    if certificate.key then
      table.insert(request.cmd, "--key")
      table.insert(request.cmd, certificate.key)
    end
  end
end

local function process_headers(request)
  for key, value in pairs(request.headers) do
    table.insert(request.cmd, "-H")
    table.insert(request.cmd, key .. ":" .. value)
  end
end

local function process_cookies(request)
  -- if the user has not specified the no-cookie meta tag,
  -- then use the cookies jar file
  if PARSER_UTILS.contains_meta_tag(request, "no-cookie-jar") == false then
    table.insert(request.cmd, "--cookie-jar")
    table.insert(request.cmd, GLOBALS.COOKIES_JAR_FILE)
  end
end

local function process_options(request)
  for _, additional_curl_option in pairs(CONFIG.get().additional_curl_options) do
    table.insert(request.cmd, additional_curl_option)
  end
end

local function toggle_chunked_mode(request)
  local chunked = vim.iter(request.metadata):find(function(m)
    return m.name == "accept" and m.value == "chunked"
  end)

  if chunked then
    table.insert(request.cmd, "-N") -- non-buffered mode: to support Transfer-Encoding: chunked
  else
    table.insert(request.cmd, "-s") -- silent mode: must be off when in Non-buffeed mode
  end
end

---Returns a DocumentRequest within specified line or the first request in the list if no line is given
---@param requests DocumentRequest[] List of document requests
---@param line_nr number|nil The line number where the request starts
---@return Request|nil -- Table containing the request data or nil if parsing fails
function M.get_basic_request_data(requests, line_nr)
  local request = vim.deepcopy(default_request)
  local document_request = DOCUMENT_PARSER.get_request_at(requests, line_nr)

  if not document_request then
    return
  end

  request.scripts.pre_request = document_request.scripts.pre_request
  request.scripts.post_request = document_request.scripts.post_request
  request.show_icon_line_number = document_request.show_icon_line_number
  request.headers = document_request.headers
  request.headers_raw = document_request.headers_raw
  request.url_raw = document_request.url
  request.method = document_request.method
  request.http_version = document_request.http_version
  request.body_raw = document_request.body
  request.body_display = document_request.body_display
  request.metadata = document_request.metadata
  request.redirect_response_body_to_files = document_request.redirect_response_body_to_files

  return request
end

---Parses a document request within specified line and returns the request ready to be processed
---or the first request in the list if no line number is provided
---or the request in DB.current_buffer current line if no arguments are provided
---or the request in current buffer at current line
---@param requests? DocumentRequest[]|nil Document requests
---@param document_variables? DocumentVariables|nil Document variables
---@param line_nr? number|nil The line number within the document to locate the request
---@return Request|nil -- Table containing the request data or nil if parsing fails
M.parse = function(requests, document_variables, line_nr)
  if not requests then
    DB.set_current_buffer()

    document_variables, requests = DOCUMENT_PARSER.get_document()
    line_nr = PARSER_UTILS.get_current_line_number()
  end

  if not requests then
    return
  end

  local request = M.get_basic_request_data(requests, line_nr)
  if not request or not request.url_raw then
    return
  end

  DB.update().previous_request = DB.find_unique("current_request")

  set_variables(request, document_variables)
  set_headers(request)
  process_graphql(request)

  local json = vim.json.encode(request)
  FS.write_file(GLOBALS.REQUEST_FILE, json, false)

  process_pre_request_scripts(request, document_variables)

  -- build the command to execute the request
  table.insert(request.cmd, CONFIG.get().curl_path)
  table.insert(request.cmd, "-D")
  table.insert(request.cmd, GLOBALS.HEADERS_FILE)
  table.insert(request.cmd, "-o")
  table.insert(request.cmd, GLOBALS.BODY_FILE)
  table.insert(request.cmd, "-w")
  table.insert(request.cmd, "@" .. CURL_FORMAT_FILE)
  table.insert(request.cmd, "-X")
  table.insert(request.cmd, request.method)
  table.insert(request.cmd, "-v") -- verbose mode

  _ = request.http_version and table.insert(request.cmd, "--http" .. request.http_version)

  toggle_chunked_mode(request)

  process_auth_headers(request)
  process_protocol(request)
  process_headers(request)
  process_body(request)
  process_cookies(request)
  process_options(request)

  table.insert(request.cmd, "-A")
  table.insert(request.cmd, "kulala.nvim/" .. GLOBALS.VERSION)
  table.insert(request.cmd, request.url)

  DB.update().current_request = request
  -- Save this to global,
  -- so .replay() can be triggered from any buffer or window
  DB.global_update().replay = vim.deepcopy(request)
  DB.global_update().replay.show_icon_line_number = nil

  cleanup_request_files()

  return request
end

return M
