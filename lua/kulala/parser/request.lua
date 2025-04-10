local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local DOCUMENT_PARSER = require("kulala.parser.document")
local ENV_PARSER = require("kulala.parser.env")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local GRAPHQL_PARSER = require("kulala.parser.graphql")
local PARSER_UTILS = require("kulala.parser.utils")
local STRING_UTILS = require("kulala.utils.string")
local CURL_FORMAT_FILE = FS.get_plugin_path({ "parser", "curl-format.json" })
local Logger = require("kulala.logger")
local Scripts = require("kulala.parser.scripts")
local StringVariablesParser = require("kulala.parser.string_variables_parser")
local Table = require("kulala.utils.table")

local M = {}

---@class Request
---@field metadata { name: string, value: string }[] -- Metadata of the request
---@field environment table<string, string|number> -- The environment and document-variables
---
---@field method string -- The HTTP method of the request
---@field url string -- The URL with variables and dynamic variables replaced
---@field url_raw string -- The raw URL as it appears in the document
---@field request_target string|nil -- The target of the request
---@field http_version string -- The HTTP version of the request
---
---@field headers table<string, string> -- The headers with variables and dynamic variables replaced
---@field headers_raw table<string, string> -- The headers as they appear in the document
---@field headers_display table<string, string> -- The headers with variables and dynamic variables replaced and sanitized
---@field cookie string -- The cookie as it appears in the document
---
---@field body string|nil -- The body with variables and dynamic variables replaced
---@field body_raw string|nil -- The raw body as it appears in the document
---@field body_computed string|nil -- The computed body as sent by curl; with variables and dynamic variables replaced
---@field body_display string|nil -- The body with variables and dynamic variables replaced and sanitized
---(e.g. with binary files replaced with a placeholder)
---
---@field show_icon_line_number number|nil -- The line number to show the icon
---
---@field redirect_response_body_to_files ResponseBodyToFile[]
---
---@field scripts Scripts -- The scripts to run before and after the request
---
---@field cmd string[] -- The command to execute the request
---@field body_temp_file string -- The path to the temporary file containing the body
---
---@field curl CurlCommand|nil -- The curl command
---@field grpc GrpcCommand|nil -- The gRPC command
---
---@field processed boolean -- Indicates if request has been already processed, used by replay()
---@field file string -- The file path of the document
---@field ft string -- The filetype of the document

---@class CurlCommand
---@field flags table<string, string> -- flags
local default_curl_command = {
  flags = {},
}

---@class GrpcCommand
---@field address string|nil -- host:port, can be omitted if proto|proto-set is provided
---@field command string|nil -- describe|list
---@field symbol string|nil -- service method in service.method or service/method format, can be omitted if command is provided
---@field flags table <string,string>--- flags: import-path|proto|proto-set|plaintext
local default_grpc_command = {
  address = nil,
  command = nil,
  symbol = nil,
  flags = {},
}

---@type Request
---@diagnostic disable-next-line: missing-fields
local default_request = {
  environment = {},
  headers_display = {},
  ft = "text",
  cmd = {},
  body_temp_file = "",
}

local function process_grpc_flags(request, flag, value)
  local grpc_global_flags = {}

  value = flag:match("import%-path") and FS.get_file_path(value) or value

  if flag:match("^global%-") then
    grpc_global_flags[flag:sub(8)] = value
  else
    request.grpc = request.grpc or vim.deepcopy(default_grpc_command)
    request.grpc.flags[flag] = value
  end

  DB.update().env.grpc = vim.tbl_extend("force", DB.find_unique("env").grpc or {}, grpc_global_flags)
end

local function process_curl_flags(request, flag, value)
  local global_flags = {}

  if flag:match("^global%-") then
    global_flags[flag:sub(8)] = value
  else
    request.curl = request.curl or vim.deepcopy(default_curl_command)
    request.curl.flags[flag] = value
  end

  DB.update().env.curl = vim.tbl_extend("force", DB.find_unique("env").curl or {}, global_flags)
end

---@param request Request
local function parse_metadata(request)
  for _, metadata in ipairs(request.metadata) do
    _ = metadata.name:find("^curl%-") and process_curl_flags(request, metadata.name:sub(6), metadata.value)
    _ = metadata.name:find("^grpc%-") and process_grpc_flags(request, metadata.name:sub(6), metadata.value)
  end
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
  if not index then return url .. anchor end

  local query = url:sub(index + 1)
  url = url:sub(1, index - 1)

  local query_parts = {}
  if query then query_parts = vim.split(query, "&") end

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

  if query_params ~= "" then url = url .. "?" .. query_params:sub(2) end
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
---@param document_variables DocumentVariables -- The variables defined in the document
---@param silent boolean|nil -- Whether to suppress not found variable warnings
local process_variables = function(request, document_variables, silent)
  if request.processed then return end

  local env = ENV_PARSER.get_env() or {}
  local params = { document_variables, env, silent }

  request.url = parse_url(request.url_raw, unpack(params))
  request.headers = parse_headers(request.headers, unpack(params))
  request.cookie = StringVariablesParser.parse(request.cookie, unpack(params))
  request.body = StringVariablesParser.parse(request.body_raw, unpack(params))
  request.body_display = StringVariablesParser.parse(request.body_display, unpack(params))
  request.body_computed = StringVariablesParser.parse(request.body_computed or request.body, unpack(params))

  request.environment = vim.tbl_extend("force", env, document_variables)

  return env
end

local function get_file_with_replaced_variables(path, request)
  local contents = FS.read_file(path)
  contents = StringVariablesParser.parse(contents, request.environment, request.environment)
  contents = contents:gsub("[\n\r]", "")

  return FS.get_temp_file(contents)
end

---Save body to a temporary file, including files specified with "< /path" syntax into request body
---NOTE: We are not saving the line endings, except "\r\n" which appear in multipart-form

---@param request Request
---@return boolean|nil status
---@return string|nil result_path path
local function save_body_with_files(request)
  local status = true
  local result_path = FS.get_binary_temp_file("")

  local result = io.open(result_path, "a+b")
  if not result then return end

  local lines = vim.split(request.body_computed, "\n")

  for _, line in ipairs(lines) do
    -- skip lines that begin with '< [file not found]'
    local path = line:match("^< ([^%[\r\n]+)[\r\n]*$")

    if path then
      if vim.fn.fnamemodify(path, ":e") == "json" then path = get_file_with_replaced_variables(path, request) end

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
  document_variables = document_variables or {}
  parse_metadata(request)

  -- INFO: if has_pre_request_script: silently replace the variables,
  -- otherwise warn the user for non existing variables
  local has_pre_request_scripts = (#request.scripts.pre_request.inline + #request.scripts.pre_request.files) > 0
  return process_variables(request, document_variables, has_pre_request_scripts)
end

local function set_headers(request, document_variables, env)
  request.headers_display = vim.deepcopy(request.headers)

  -- Merge headers from the $shared environment if it does not exist in the request
  -- this ensures that you can always override the headers in the request
  local default_headers = (DB.find_unique("http_client_env_shared") or {})["$default_headers"] or {}

  local cur_env = vim.g.kulala_selected_env or CONFIG.get().default_env
  local default_headers_env = vim.tbl_get(DB.find_unique("http_client_env") or {}, cur_env, "$default_headers") or {}

  default_headers = vim.tbl_extend("force", default_headers, default_headers_env)

  vim.iter(default_headers):each(function(name, value)
    name = PARSER_UTILS.get_header(request.headers, name) or name
    value = StringVariablesParser.parse(value, document_variables, env)

    if name == "Host" then
      request.url = (request.url == "" or request.url:match("^/")) and (value .. request.url) or request.url
    else
      request.headers[name] = request.headers[name] or StringVariablesParser.parse(value, document_variables, env)
    end
  end)
end

local function process_graphql(request)
  local is_graphql = request.method == "GRAPHQL"
    or PARSER_UTILS.contains_meta_tag(request, "graphql")
    or PARSER_UTILS.contains_header(request.headers, "x-request-type", "graphql")

  if request.body and #request.body > 0 and is_graphql then
    local gql_json = GRAPHQL_PARSER.get_json(request.body)

    if gql_json then
      local content_type_header_name = PARSER_UTILS.get_header(request.headers, "Content-Type") or "Content-Type"

      request.headers[content_type_header_name] = "application/json"
      request.body_computed = gql_json
    end
  end
  return request
end

local function process_pre_request_scripts(request, document_variables)
  if #request.scripts.pre_request.inline + #request.scripts.pre_request.files == 0 then return true end

  Scripts.run("pre_request", request)

  -- INFO: now replace the variables in the URL, headers and body again,
  -- because user scripts could have changed them,
  -- but this time also warn the user if a variable is not found
  process_variables(request, document_variables)

  return not (request.environment["__skip_request"] == "true")
end

local function process_body(request)
  local content_type_header_name, content_type_header_value = PARSER_UTILS.get_header(request.headers, "content-type")

  if content_type_header_name and content_type_header_value and request.body and #request.body_computed > 0 then
    local status, path = save_body_with_files(request)

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
  if not (auth_header_name and auth_header_value) then return end

  local authtype = auth_header_value:match("^(%w+)%s+.*")
  if not authtype then authtype = auth_header_value:match("^(%w+)%s*$") end

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

      if region then provider = provider .. ":" .. region end
      if service then provider = provider .. ":" .. service end

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

  if protocol ~= "https" then return end

  local certificate = CONFIG.get().certificates[host .. ":" .. (port or "443")]
  if not certificate then certificate = CONFIG.get().certificates[host] end

  if not certificate then
    while host ~= "" do
      certificate = CONFIG.get().certificates["*." .. host .. ":" .. (port or "443")]

      if not certificate then certificate = CONFIG.get().certificates["*." .. host] end
      if certificate then break end

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

  if #request.cookie > 0 then
    table.insert(request.cmd, "--cookie")
    table.insert(request.cmd, request.cookie)
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

-- GPRC localhost:50051 helloworld.Greeter/SayHello
-- GRPC localhost:50051 describe helloworld.Greeter.SayHello
-- GRPC localhost:50051 describe|list
-- GRPC -d '{"name": "world"}' -import-path ../protos -proto helloworld.proto -plaintext localhost:50051 helloworld.Greeter/SayHello
local function parse_grpc_command(request)
  local grpc_cmd = vim.deepcopy(default_grpc_command)

  local address_parsed = false
  local previous_flag = nil

  return vim.iter(vim.split(request.url, " ")):fold(grpc_cmd, function(cmd, part)
    if part:find("GRPC") then -- method
      -- skip
    elseif part:find(":") then -- address
      cmd.address = part
      address_parsed = true
    elseif part:match("^describe$") or part:match("^list$") then -- command
      cmd.command = part
    elseif part:find("[^:].+") and address_parsed then -- symbol
      cmd.symbol = part
    elseif part:find("^%-") then -- flag
      previous_flag = part:sub(2)
      process_grpc_flags(request, previous_flag, "")
    elseif previous_flag then -- previous flag value
      process_grpc_flags(request, previous_flag, part)
      previous_flag = nil
    end

    return cmd
  end)
end

-- executable, flag, address, command, symbol
local function build_grpc_command(request)
  local grpc_command = parse_grpc_command(request)

  table.insert(request.cmd, CONFIG.get().grpcurl_path)

  if request.body_computed and #request.body_computed > 1 then
    table.insert(request.cmd, "-d") -- data
    table.insert(request.cmd, request.body_computed)
  end

  local flags = vim.tbl_extend("force", DB.find_unique("env").grpc or {}, request.grpc and request.grpc.flags or {})
  vim.iter(flags):each(function(flag, value)
    table.insert(request.cmd, "-" .. flag)
    _ = (value and #value > 1) and table.insert(request.cmd, value)
  end)

  _ = grpc_command.address and table.insert(request.cmd, grpc_command.address)
  _ = grpc_command.command and table.insert(request.cmd, grpc_command.command)
  _ = grpc_command.symbol and table.insert(request.cmd, grpc_command.symbol)
end

local function build_curl_command(request)
  table.insert(request.cmd, CONFIG.get().curl_path)
  table.insert(request.cmd, "-D")
  table.insert(request.cmd, FS.normalize_path(GLOBALS.HEADERS_FILE))
  table.insert(request.cmd, "-o")
  table.insert(request.cmd, FS.normalize_path(GLOBALS.BODY_FILE))
  table.insert(request.cmd, "-w")
  table.insert(request.cmd, "@" .. FS.normalize_path(CURL_FORMAT_FILE))

  _ = request.request_target and vim.list_extend(request.cmd, { "--request-target", request.request_target })

  table.insert(request.cmd, "-X")
  table.insert(request.cmd, request.method)
  table.insert(request.cmd, "-v") -- verbose mode

  _ = request.http_version and table.insert(request.cmd, "--http" .. request.http_version)

  toggle_chunked_mode(request)

  local flags = vim.tbl_extend("force", DB.find_unique("env").curl or {}, request.curl and request.curl.flags or {})
  vim.iter(flags):each(function(flag, value)
    local prefix = #flag > 1 and "--" or "-"
    table.insert(request.cmd, prefix .. flag)
    _ = (value and #value > 1) and table.insert(request.cmd, value)
  end)

  process_auth_headers(request)
  process_protocol(request)
  process_headers(request)
  process_body(request)
  process_cookies(request)
  process_options(request)

  table.insert(request.cmd, "-A")
  table.insert(request.cmd, "kulala.nvim/" .. GLOBALS.VERSION)
  table.insert(request.cmd, request.url)
end

---Gets data from specified DocumentRequest or a request within specified line or the first request in the list if no request or line is provided
---@param requests DocumentRequest[] List of document requests
---@param request DocumentRequest|nil The request to parse
---@param line_nr number|nil The line number where the request starts
---@return Request|nil -- Table containing the request data or nil if parsing fails
function M.get_basic_request_data(requests, document_request, line_nr)
  local request = vim.deepcopy(default_request)
  document_request = document_request and { document_request } or DOCUMENT_PARSER.get_request_at(requests, line_nr)
  document_request = #document_request > 0 and document_request[1]

  if not document_request then return end

  request = vim.tbl_extend("keep", request, document_request)

  request.url_raw = document_request.url
  request.body_raw = document_request.body

  Table.remove_keys(request, { "name", "body", "variables", "start_line", "end_line" })

  return request
end

---Parses specified document request or a request within specified line and returns the request ready to be processed
---or the first request in the list if no document_request or line number is provided
---or the request in current_buffer at current line if no arguments are provided
---@param requests? DocumentRequest[]|nil Document requests
---@param document_variables? DocumentVariables|nil Document variables
---@param document_request? DocumentRequest|nil The request to parse
---@return Request|nil -- Table containing the request data or nil if parsing fails
---@return string|nil -- Error message if parsing fails
M.parse = function(requests, document_variables, document_request)
  local line_nr

  if not requests then
    DB.set_current_buffer()

    document_variables, requests = DOCUMENT_PARSER.get_document()
    line_nr = PARSER_UTILS.get_current_line_number()
  end

  if not requests then return end

  local request = M.get_basic_request_data(requests, document_request, line_nr)
  if not request then return end

  if not request.processed then
    local env = set_variables(request, document_variables)
    set_headers(request, document_variables, env)
    process_graphql(request)
  end

  local json = vim.json.encode(request)
  FS.write_file(GLOBALS.REQUEST_FILE, json, false)

  if not process_pre_request_scripts(request, document_variables) then return nil, "skipped" end

  if request.method == "GRPC" then
    build_grpc_command(request)
  else
    build_curl_command(request)
  end

  DB.update().previous_request = DB.find_unique("current_request")
  DB.update().current_request = request

  -- Save this to global, so .replay() can be triggered from any buffer or window
  DB.global_update().replay = vim.deepcopy(request)
  DB.global_update().replay.show_icon_line_number = nil
  DB.global_update().replay.processed = true

  return request
end

M.process_variables = process_variables

return M
