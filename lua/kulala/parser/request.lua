local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local DOCUMENT_PARSER = require("kulala.parser.document")
local ENV_PARSER = require("kulala.parser.env")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local GRAPHQL_PARSER = require("kulala.parser.graphql")
local PARSER_UTILS = require("kulala.parser.utils")
local STRING_UTILS = require("kulala.utils.string")
local CURL_FORMAT_FILE = FS.get_plugin_path { "parser", "curl-format.json" }
local Logger = require("kulala.logger")
local Scripts = require("kulala.parser.scripts")
local StringVariablesParser = require("kulala.parser.string_variables_parser")
local Table = require("kulala.utils.table")

local M = {}

---@class Request: DocumentRequest
---@field metadata { name: string, value: string }[] -- Metadata of the request
---@field variables table<{name: string, value: string|number|boolean}>
---@field environment table<string, string|number> -- The environment and request variables
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
---@field curl CurlCommand -- The curl command
---@field grpc GrpcCommand|nil -- The gRPC command
---
---@field file string -- The file path of the document
---@field ft string -- The filetype of the document

---@class CurlCommand
---@field flags table<string, string> -- flags

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
  curl = { flags = {} },
}

local function process_grpc_flags(request, flag, value)
  if flag:match("global") then
    return Logger.warn("The `grpc-global-` flags are deprecated.  Please use `Shared` blocks.")
  end

  value = flag:match("import%-path") and FS.get_file_path(value) or value
  request.grpc = request.grpc or vim.deepcopy(default_grpc_command)

  local last_flag = request.grpc.flags[#request.grpc.flags] or {}

  if value ~= "" and last_flag[1] == flag and last_flag[2] == "" then
    request.grpc.flags[#request.grpc.flags][2] = value
  else
    table.insert(request.grpc.flags, { flag, value })
  end
end

local function process_curl_flags(request, flag, value)
  if flag:match("global") then
    return Logger.warn("The `curl-global-` flags are deprecated.  Please use `Shared` blocks.")
  end

  request.curl.flags[flag] = value
end

---@param request Request
local function parse_metadata(request)
  for _, metadata in ipairs(request.metadata) do
    _ = metadata.name:find("^curl%-") and process_curl_flags(request, metadata.name:sub(6), metadata.value)
    _ = metadata.name:find("^grpc%-") and process_grpc_flags(request, metadata.name:sub(6), metadata.value)
  end
end

-- Reserved Characters: ! # $ & ' ( ) * + , / : ; = ? @ [ ]
-- https://stackoverflow.com/questions/1547899/which-characters-make-a-url-invalid/1547940#1547940
local function encode_url(url, method)
  local urlencode = CONFIG.get().urlencode == "always"
  if urlencode and vim.uri_decode(url) ~= url then return url end

  local index
  local scheme, authority, path, query, fragment = "", "", "", "", ""
  local url_encode = urlencode and STRING_UTILS.url_encode or STRING_UTILS.url_encode_skipencoded

  if method == "GRPC" then return url_encode(url, "/:%s") end

  _, index = url:find(".*#")
  if index then
    fragment = url_encode(url:sub(index), "#/%(%)!$',*")
    url = url:sub(1, index - 1)
  end

  _, index = url:find(".*?")
  if index then
    query = url_encode(url:sub(index), "%?/=&%(%)!$',*")
    url = url:sub(1, index - 1)
  end

  _, index = url:find(".*://")
  if index then
    scheme = url_encode(url:sub(1, index - 3), "+") .. "://"
    url = url:sub(index + 1)
  end

  index = url:find("/")
  if index then
    authority = url_encode(url:sub(1, index - 1), "@:%[%]")
    url = url:sub(index)
  end

  path = url_encode(url, "/:;=%[%]%(%)!$',*")

  return scheme .. authority .. path .. query .. fragment
end

local function parse_url(url, variables, env, silent)
  return StringVariablesParser.parse(url, variables, env, silent)
end

local function parse_headers(headers, variables, env, silent)
  return vim.iter(headers):fold({}, function(ret, k, v)
    ret[StringVariablesParser.parse(k, variables, env, silent)] = StringVariablesParser.parse(v, variables, env, silent)
    return ret
  end)
end

---Replace the variables in the URL, headers and body
---@param request Request -- The request object
---@param silent boolean|nil -- Whether to suppress not found variable warnings
local process_variables = function(request, silent)
  local env = ENV_PARSER.get_env() or {}
  local params = { request.variables, env, silent }

  request.url = parse_url(request.url_raw, unpack(params))
  request.headers = parse_headers(request.headers, unpack(params))
  request.cookie = StringVariablesParser.parse(request.cookie, unpack(params))
  request.body = StringVariablesParser.parse(request.body_raw, unpack(params))
  request.body_display = StringVariablesParser.parse(request.body_display, unpack(params))
  request.body_computed = StringVariablesParser.parse(request.body_raw, unpack(params))

  vim.iter(request.redirect_response_body_to_files):each(function(redirect)
    redirect.file = StringVariablesParser.parse(redirect.file, unpack(params))
  end)

  vim.iter(request.metadata):each(function(metadata)
    metadata.value = StringVariablesParser.parse(metadata.value, unpack(params))
  end)

  request.environment = vim.tbl_extend("keep", env, request.variables)

  return env
end

local function get_file_with_replaced_variables(path, request)
  local contents = FS.read_file(path)

  if vim.fn.fnamemodify(path, ":e") == "graphql" or vim.fn.fnamemodify(path, ":e") == "gql" then
    contents = contents:gsub("#[^\n]*", "") -- remove comments from GraphQL files
  end

  contents = StringVariablesParser.parse(contents, request.environment, request.environment)
  contents = contents:gsub("[\n\r]", "")

  return FS.get_temp_file(contents), contents
end

---Save body to a temporary file, including files specified with "< /path" syntax into request body
---@param request Request
---@return boolean|nil status
---@return string|nil result_path path
local function save_body_with_files(request)
  local extensions = { "json", "graphql", "gql" }

  local status = true
  local graphql = false
  local result_path = FS.get_binary_temp_file("")

  local result = io.open(result_path, "a+b")
  if not result then return end

  local lines = vim.split(request.body_computed, "\n")

  for i, line in ipairs(lines) do
    -- skip lines that begin with '< [file not found]'
    local path = line:match("^< ([^%[\r\n]+)[\r\n]*$")

    if path then
      local ext = vim.fn.fnamemodify(path, ":e")

      if vim.tbl_contains(extensions, ext) then path = get_file_with_replaced_variables(path, request) end

      if not FS.include_file(result, path) then
        Logger.warn("The file '" .. path .. "' could not be included. Skipping ...")
      end

      if ext == "graphql" or ext == "gql" then
        graphql = true
        result:write("\n") -- to separate query and variables
      end
    else
      line = (i ~= #lines or line:find("\r$")) and (line .. "\n") or line -- add newline only for multipart/form-data and if not last line
      ---@diagnostic disable-next-line: cast-local-type
      status = status and result:write(line)
    end
  end

  status = status and result:close()

  if graphql then -- to process GraphQL query included from external file
    local query = GRAPHQL_PARSER.get_json(FS.read_file(result_path))
    FS.write_file(result_path, query or "{}")
  end

  return status, result_path
end

local function set_variables(request)
  local has_pre_request_scripts = (#request.scripts.pre_request.inline + #request.scripts.pre_request.files) > 0

  local variables = process_variables(request, has_pre_request_scripts)
  parse_metadata(request)

  return variables
end

local function set_headers(request, env)
  request.headers_display = vim.deepcopy(request.headers)

  local cur_env = vim.g.kulala_selected_env or CONFIG.get().default_env
  local shared_headers = vim.tbl_get(DB.find_unique("http_client_env_shared") or {}, "$default_headers") or {}
  local default_headers = vim.tbl_get(DB.find_unique("http_client_env") or {}, cur_env, "$default_headers") or {}

  local headers = vim.tbl_extend("force", shared_headers, default_headers, request.headers)

  vim.iter(headers):each(function(name, value)
    name = PARSER_UTILS.get_header(request.headers, name) or name
    value = StringVariablesParser.parse(value, request.variables, env)

    if name == "Host" then
      request.headers[name] = value:gsub("^https?://", ""):gsub("/.*$", "")
      request.url = (request.url == "" or request.url:match("^/")) and (value .. request.url) or request.url
    else
      request.headers[name] = request.headers[name] or StringVariablesParser.parse(value, request.variables, env)
    end
  end)
end

local function process_graphql(request)
  local has_graphql_meta_tag = PARSER_UTILS.contains_meta_tag(request, "graphql")
  local has_graphql_header = PARSER_UTILS.contains_header(request.headers, "x-request-type", "graphql")

  local is_graphql = request.method == "GRAPHQL" or has_graphql_meta_tag or has_graphql_header

  if is_graphql and request.body and #request.body > 0 then
    local content_type_header_name = PARSER_UTILS.get_header(request.headers, "Content-Type") or "Content-Type"

    request.method = "POST"
    request.headers[content_type_header_name] = "application/json"

    if not has_graphql_header then request.headers["x-request-type"] = "GraphQL" end

    request.body_computed = request.body:gsub("\n<%s([^\n]+)", function(path)
      local _, contents = get_file_with_replaced_variables(path, request)
      return contents and ("\n" .. contents) or ""
    end)

    local gql_json = GRAPHQL_PARSER.get_json(request.body_computed)
    if gql_json then request.body_computed = gql_json end
  end

  return request
end

local function process_pre_request_scripts(request)
  if #request.scripts.pre_request.inline + #request.scripts.pre_request.files == 0 then return true end

  Scripts.run("pre_request", request)

  -- Process variables and headers again in case pre-request scripts modified them
  process_variables(request)
  set_headers(request, request.environment)

  local skip = request.environment["__skip_request"] == "true"
  request.environment["__skip_request"] = nil

  return not skip
end

local function process_body(request)
  local content_type_header_name, content_type_header_value = PARSER_UTILS.get_header(request.headers, "content-type")

  if content_type_header_name and content_type_header_value and request.body and #request.body_computed > 0 then
    if content_type_header_value == "application/x-www-form-urlencoded" then
      request.body_computed = request.body_computed:gsub("\n", "")
    end

    local status, path = save_body_with_files(request)

    if status then
      request.body_temp_file = path
      table.insert(request.cmd, request.curl.flags["data-urlencode"] and "--data-urlencode" or "--data-binary")
      table.insert(request.cmd, "@" .. path)
    else
      Logger.error("Failed to create a temporary file for the request body")
    end
  end
end

local function process_auth_headers(request)
  local auth_header_name, auth_header_value = PARSER_UTILS.get_header(request.headers, "authorization")
  if not (auth_header_name and auth_header_value) then return end

  local _, index, authtype = auth_header_value:find("^(%w+)%s*")

  if authtype then
    authtype = authtype:lower()
    if vim.tbl_contains({ "ntlm", "negotiate", "digest", "basic" }, authtype) then
      local authvalue = auth_header_value:sub(index + 1)

      local authuser, authpw = authvalue:match("^(.*):(.+)$")

      if authuser or (authtype == "ntlm" or authtype == "negotiate") then
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
      -- Add password to cert if provided
      local cert_value = certificate.cert
      if certificate.password then cert_value = cert_value .. ":" .. certificate.password end
      table.insert(request.cmd, cert_value)
    end

    if certificate.key then
      table.insert(request.cmd, "--key")
      table.insert(request.cmd, certificate.key)
    end

    if certificate.cacert then
      table.insert(request.cmd, "--cacert")
      table.insert(request.cmd, certificate.cacert)
    end
  end
end

local function process_headers(request)
  for key, value in pairs(request.headers) do
    value = value == "" and ";" or ":" .. value
    table.insert(request.cmd, "-H")
    table.insert(request.cmd, key .. value)
  end
end

local function process_cookies(request)
  if CONFIG.options.write_cookies and not PARSER_UTILS.contains_meta_tag(request, "no-cookie-jar") then
    table.insert(request.cmd, "--cookie-jar")
    table.insert(request.cmd, GLOBALS.COOKIES_JAR_FILE)
  end

  if #request.cookie > 0 then
    table.insert(request.cmd, "--cookie")
    table.insert(request.cmd, request.cookie)
  end

  if PARSER_UTILS.contains_meta_tag(request, "attach-cookie-jar") == true then
    table.insert(request.cmd, "--cookie")
    table.insert(request.cmd, GLOBALS.COOKIES_JAR_FILE)
  end
end

local function process_custom_curl_flags(request)
  local env = DB.find_unique("http_client_env") or {}

  local flags = vim.list_extend({}, CONFIG.get().additional_curl_options or {})
  local ssl_config = vim.tbl_get(env, ENV_PARSER.get_current_env(), "SSLConfiguration", "verifyHostCertificate")

  if ssl_config == false and not vim.tbl_contains(flags, "--insecure") and not vim.tbl_contains(flags, "-k") then
    table.insert(flags, "--insecure")
  end

  vim.iter(request.curl.flags):each(function(flag, value)
    if flag == "-k" or flag == "--insecure" then return end

    if flag == "data-urlencode" then
      request.curl.flags["data-urlencode"] = ""
      return
    end

    local prefix = #flag > 1 and "--" or "-"
    table.insert(flags, prefix .. flag)
    _ = (value and #value > 0) and table.insert(flags, value)
  end)

  vim.iter(flags):each(function(flag)
    table.insert(request.cmd, flag)
  end)

  return flags
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
    elseif part:find(":") and not part:find("=") then -- address
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

  local flags = request.grpc and request.grpc.flags or {}
  vim.iter(flags):each(function(flag_value)
    local f, v = unpack(flag_value)
    table.insert(request.cmd, "-" .. f)
    _ = (v and #v > 1) and table.insert(request.cmd, v)
  end)

  vim.iter(request.headers):each(function(key, value)
    value = value == "" and ";" or ":" .. value
    table.insert(request.cmd, "-H")
    table.insert(request.cmd, key .. value)
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

  _ = #request.request_target > 0 and vim.list_extend(request.cmd, { "--request-target", request.request_target })

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
  process_custom_curl_flags(request)

  table.insert(request.cmd, "-A")
  table.insert(request.cmd, "kulala.nvim/" .. GLOBALS.VERSION)
  table.insert(request.cmd, request.url)
end

---Gets data from specified DocumentRequest or a request within specified line or the first request in the list if no request or line is provided
---@param requests DocumentRequest[] List of document requests
---@param document_request DocumentRequest|nil The request to parse
---@param line_nr number|nil The line number where the request starts
---@return Request|nil -- Table containing the request data or nil if parsing fails
function M.get_basic_request_data(requests, document_request, line_nr)
  local request = vim.deepcopy(default_request)

  if not document_request then
    local doc_requests = DOCUMENT_PARSER.get_request_at(requests, line_nr) or {}
    -- return shared requests if it is the only one
    document_request = line_nr and line_nr > 0 and doc_requests[2] or doc_requests[1]
  end

  if not document_request then return end

  request = vim.tbl_extend("keep", request, document_request)

  request.url_raw = request.url_raw or document_request.url -- url_raw may be already set if the request is being replayed
  request.body_raw = document_request.body

  Table.remove_keys(request, { "comments", "body" })

  return request
end

---Parses specified document request or a request within specified line and returns the request ready to be processed
---or the first request in the list if no document_request or line number is provided
---or the request in current_buffer at current line if no arguments are provided
---@param requests? DocumentRequest[]|nil Document requests
---@param document_request? DocumentRequest|nil The request to parse
---@return Request|nil -- Table containing the request data or nil if parsing fails
---@return string|nil -- Error message if parsing fails
M.parse = function(requests, document_request)
  local line_nr

  if not requests then
    DB.set_current_buffer()
    requests = DOCUMENT_PARSER.get_document()
    line_nr = PARSER_UTILS.get_current_line_number()
  end

  if not requests or #requests == 0 then return end

  local request = M.get_basic_request_data(requests, document_request, line_nr)
  if not request then return end

  DB.current_request = request

  local empty_request = false
  if not request.url then empty_request = true end -- shared blocks with no URL

  local env = set_variables(request)
  set_headers(request, env)

  request.url = encode_url(request.url, request.method)
  process_graphql(request)

  local json = vim.json.encode(request)
  FS.write_file(GLOBALS.REQUEST_FILE, json, false)

  if not process_pre_request_scripts(request) then return nil, "skipped" end
  if empty_request then
    Scripts.run("post_request", request)
    return nil, "empty"
  end

  if request.method == "GRPC" then
    build_grpc_command(request)
  else
    build_curl_command(request)
  end

  DB.update().previous_request = DB.find_unique("current_request")
  DB.update().current_request = request

  -- Save this to global, so .replay() can be triggered from any buffer or window
  DB.global_update().replay = vim.deepcopy(request)
  DB.global_update().replay.url_raw = request.url
  DB.global_update().replay.show_icon_line_number = nil

  return request
end

M.process_variables = process_variables
M.parse_metadata = parse_metadata
M.process_custom_curl_flags = process_custom_curl_flags

return M
