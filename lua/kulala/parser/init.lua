local M = {}
M.scripts = {}
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local DYNAMIC_VARS = require("kulala.parser.dynamic_vars")
local ENV_PARSER = require("kulala.parser.env")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local GRAPHQL_PARSER = require("kulala.parser.graphql")
local REQUEST_VARIABLES = require("kulala.parser.request_variables")
local STRING_UTILS = require("kulala.utils.string")
local PARSER_UTILS = require("kulala.parser.utils")
local TS = require("kulala.parser.treesitter")
local CURL_FORMAT_FILE = FS.get_plugin_path({ "parser", "curl-format.json" })
local Logger = require("kulala.logger")

M.scripts.javascript = require("kulala.parser.scripts.javascript")

---Parse the variables in a string
---@param str string -- The string to parse
---@param variables table -- The variables defined in the document
---@param env table -- The environment variables
---@param silent boolean|nil -- Whether to suppress not found variable warnings
local function parse_string_variables(str, variables, env, silent)
  local function replace_placeholder(variable_name)
    local value
    -- If the variable name contains a `$` symbol then try to parse it as a dynamic variable
    if variable_name:find("^%$") then
      local variable_value = DYNAMIC_VARS.read(variable_name)
      if variable_value then
        value = variable_value
      end
    elseif variables[variable_name] then
      value = parse_string_variables(variables[variable_name], variables, env)
    elseif env[variable_name] then
      value = env[variable_name]
    elseif REQUEST_VARIABLES.parse(variable_name) then
      value = REQUEST_VARIABLES.parse(variable_name)
    else
      value = "{{" .. variable_name .. "}}"
      if not silent then
        Logger.info(
          "The variable '"
            .. variable_name
            .. "' was not found in the document or in the environment. Returning the string as received ..."
        )
      end
    end
    return value
  end
  local result = str:gsub("{{(.-)}}", replace_placeholder)
  return result
end

local function parse_headers(headers, variables, env, silent)
  local h = {}
  for key, value in pairs(headers) do
    h[key] = parse_string_variables(value, variables, env, silent)
  end
  return h
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
  if index == nil then
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
  url = parse_string_variables(url, variables, env, silent)
  url = encode_url_params(url)
  url = url:gsub('"', "")
  return url
end

--- Parse the body of the request
---@param body string|nil -- The body of the request
---@param variables table|nil -- The variables defined in the document
---@param env table|nil -- The environment variables
---@param silent boolean|nil -- Whether to suppress not found variable warnings
local function parse_body(body, variables, env, silent)
  if body == nil then
    return nil
  end
  variables = variables or {}
  env = env or {}
  return parse_string_variables(body, variables, env, silent)
end

--- Parse the body_display of the request
---@param body_display string|nil -- The body of the request
---@param variables table|nil -- The variables defined in the document
---@param env table|nil -- The environment variables
---@param silent boolean|nil -- Whether to suppress not found variable warnings
local function parse_body_display(body_display, variables, env, silent)
  if body_display == nil then
    return nil
  end
  variables = variables or {}
  env = env or {}
  return parse_string_variables(body_display, variables, env, silent)
end

local function split_by_block_delimiters(text)
  local result = {}
  local start = 1
  -- Pattern to match lines starting with ### followed by optional text and ending with a newline
  local pattern = "\n###.-\n"
  while true do
    -- Find the next delimiter
    local split_start, split_end = text:find(pattern, start)
    if not split_start then
      -- If no more delimiters, add the remaining text as the last section
      local last_section = text:sub(start):gsub("\n+$", "") -- Remove trailing newlines
      if #last_section > 0 then
        table.insert(result, last_section)
      end
      break
    end
    -- Add the text before the delimiter as a section
    local section = text:sub(start, split_start - 1):gsub("\n+$", "") -- Remove trailing newlines
    if #section > 0 then
      table.insert(result, section)
    end
    -- Move start position
    start = split_end
  end
  return result
end

local function get_request_from_fenced_code_block()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local start_line = cursor_pos[1]

  -- Get the total number of lines in the current buffer
  local total_lines = vim.api.nvim_buf_line_count(0)

  -- Search for the start of the fenced code block (``` or similar)
  local block_start = nil
  for i = start_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if line:match("^%s*```") then
      block_start = i
      break
    end
  end

  -- If we didn't find a block start, return nil
  if not block_start then
    return nil, nil
  end

  -- Search for the end of the fenced code block
  local block_end = nil
  for i = start_line, total_lines do
    local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if line:match("^%s*```") then
      block_end = i
      break
    end
  end

  -- If we didn't find a block end, return nil
  if not block_end then
    return nil, nil
  end

  return vim.api.nvim_buf_get_lines(0, block_start, block_end - 1, false), block_start
end

M.get_document = function()
  local line_offset
  local content_lines

  if CONFIG.get().treesitter then
    return TS.get_document()
  end

  local maybe_from_fenced_code_block = FS.is_non_http_file()

  if maybe_from_fenced_code_block then
    content_lines, line_offset = get_request_from_fenced_code_block()
  else
    content_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    line_offset = 0
  end

  if not content_lines then
    return nil, nil
  end

  local content = table.concat(content_lines, "\n")
  local variables = {}
  local requests = {}
  local blocks = split_by_block_delimiters(content)
  for _, block in ipairs(blocks) do
    local is_request_line = true
    local is_prerequest_handler_script_inline = false
    local is_postrequest_handler_script_inline = false
    local is_body_section = false
    local lines = vim.split(block, "\n")
    local block_line_count = #lines
    local request = {
      headers = {},
      headers_raw = {},
      metadata = {},
      body = nil,
      body_display = nil,
      show_icon_line_number = nil,
      start_line = line_offset + 1,
      block_line_count = block_line_count,
      lines_length = #lines,
      variables = {},
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
    }
    for relative_linenr, line in ipairs(lines) do
      -- end of inline scripting
      if is_request_line == true and line:match("^%%}$") then
        is_prerequest_handler_script_inline = false
      -- end of inline scripting
      elseif is_body_section == true and line:match("^%%}$") then
        is_postrequest_handler_script_inline = false
      -- inline scripting active: add the line to the response handler scripts
      elseif is_postrequest_handler_script_inline then
        table.insert(request.scripts.post_request.inline, line)
      -- inline scripting active: add the line to the prerequest handler scripts
      elseif is_prerequest_handler_script_inline then
        table.insert(request.scripts.pre_request.inline, line)
      elseif line:sub(1, 1) == "#" then
        -- Metadata (e.g., # @this-is-name this is the value)
        -- See: https://httpyac.github.io/guide/metaData.html
        if line:sub(1, 3) == "# @" then
          local meta_name, meta_value = line:match("^# @([%w+%-]+)%s*(.*)$")
          if meta_name and meta_value then
            table.insert(request.metadata, { name = meta_name, value = meta_value })
          end
        end
      -- we're still in(/before) the request line and we have a pre-request inline handler script
      elseif is_request_line == true and line:match("^< %{%%$") then
        is_prerequest_handler_script_inline = true
      -- we're still in(/before) the request line and we have a pre-request file handler script
      elseif is_request_line == true and line:match("^< (.*)$") then
        local scriptfile = line:match("^< (.*)$")
        table.insert(request.scripts.pre_request.files, scriptfile)
      elseif line == "" and is_body_section == false then
        if is_request_line == false then
          is_body_section = true
        end
      -- redirect response body to file, without overwriting
      elseif line:match("^>> (.*)$") then
        local write_to_file = line:match("^>> (.*)$")
        table.insert(request.redirect_response_body_to_files, {
          file = write_to_file,
          overwrite = false,
        })
      -- redirect response body to file, with overwriting
      elseif line:match("^>>! (.*)$") then
        local write_to_file = line:match("^>>! (.*)$")
        table.insert(request.redirect_response_body_to_files, {
          file = write_to_file,
          overwrite = true,
        })
      -- start of inline scripting
      elseif line:match("^> {%%$") then
        is_postrequest_handler_script_inline = true
      -- file scripting notation
      elseif line:match("^> (.*)$") then
        local scriptfile = line:match("^> (.*)$")
        table.insert(request.scripts.post_request.files, scriptfile)
      elseif line:match("^@([%w_]+)") then
        -- Variable
        -- Variables are defined as `@variable_name=value`
        -- The value can be a string, a number or boolean
        local variable_name, variable_value = line:match("^@([%w_]+)%s*=%s*(.*)$")
        if variable_name and variable_value then
          -- remove the @ symbol from the variable name
          variable_name = variable_name:sub(1)
          variables[variable_name] = variable_value
        end
      elseif is_body_section == true then
        local _, content_type_header_value = PARSER_UTILS.get_header(request.headers, "content-type")
        -- If the request body is nil, this also means that the body_display is nil
        -- so we need to initialize it to an empty string, because the header value content-type
        -- is present and implies that there is a body to be sent
        if request.body == nil then
          request.body = ""
          request.body_display = ""
        end
        if line:find("^<") then
          if content_type_header_value ~= nil and content_type_header_value:find("^multipart/form%-data") then
            request.body = request.body .. line .. "\r\n"
            request.body_display = request.body_display .. line .. "\r\n"
          else
            local file_path = vim.trim(line:sub(2))
            local contents = FS.read_file(file_path)
            if contents ~= nil then
              request.body = request.body .. contents .. "\r\n"
              request.body_display = request.body_display .. "[[external file skipped]]\r\n"
            else
              Logger.warn("The file '" .. file_path .. "' was not found. Skipping ...")
            end
          end
        else
          if content_type_header_value ~= nil and content_type_header_value:find("^multipart/form%-data") then
            request.body = request.body .. line .. "\r\n"
            request.body_display = request.body_display .. line .. "\r\n"
          elseif
            content_type_header_value ~= nil
            and content_type_header_value:find("^application/x%-www%-form%-urlencoded")
          then
            request.body = request.body .. line
            request.body_display = request.body_display .. line
          else
            request.body = request.body .. line .. "\r\n"
            request.body_display = request.body_display .. line .. "\r\n"
          end
        end
      elseif is_request_line == false and line:match("^%s*[?&]") and #request.headers == 0 and request.url then
        -- Query parameters for URL as separate lines
        local querypart, http_version = line:match("^%s*(.+)%s+HTTP/(%d[.%d]*)%s*$")
        if querypart == nil then
          querypart = line:match("^%s*(.+)%s*$")
        end
        if querypart then
          request.url = request.url .. querypart
        end
        if http_version then
          request.http_version = http_version
        end
      elseif is_request_line == false and line:match("^([^:]+):%s*(.*)$") then
        -- Header
        -- Headers are defined as `key: value`
        -- The key is case-insensitive
        -- The key can be anything except a colon
        -- The value can be a string or a number
        -- The value can be a variable
        -- The value can be a dynamic variable
        -- variables are defined as `{{variable_name}}`
        -- dynamic variables are defined as `{{$variable_name}}`
        local key, value = line:match("^([^:]+):%s*(.*)$")
        if key and value then
          request.headers[key] = value
          request.headers_raw[key] = value
        end
      elseif is_request_line == true then
        -- Request line (e.g., GET http://example.com HTTP/1.1)
        -- Split the line into method, URL and HTTP version
        -- HTTP Version is optional
        request.method, request.url, request.http_version = line:match("^([A-Z]+)%s+(.+)%s+HTTP/(%d[.%d]*)%s*$")
        if request.method == nil then
          request.method, request.url = line:match("^([A-Z]+)%s+(.+)$")
        end
        local show_icons = CONFIG.get().show_icons
        if show_icons ~= nil then
          if show_icons == "on_request" then
            request.show_icon_line_number = request.start_line + relative_linenr - 1
          elseif show_icons == "above_request" then
            request.show_icon_line_number = request.start_line + relative_linenr - 2
          elseif show_icons == "below_request" then
            request.show_icon_line_number = request.start_line + relative_linenr
          end
        end
        is_request_line = false
      end
    end
    if request.body ~= nil then
      request.body = vim.trim(request.body)
      request.body_display = vim.trim(request.body_display)
    end
    request.end_line = line_offset + block_line_count
    line_offset = request.end_line + 1 -- +1 for the '###' separator line
    table.insert(requests, request)
  end
  return variables, requests
end

M.get_request_at = function(requests, linenr)
  if requests == nil then
    Logger.error("No requests found in the document")
    return nil
  end
  if linenr == nil then
    linenr = vim.api.nvim_win_get_cursor(0)[1]
  end
  if CONFIG.get().treesitter then
    return TS.get_request_at(linenr - 1)
  end
  for _, request in ipairs(requests) do
    if linenr >= request.start_line and linenr <= request.end_line then
      return request
    end
  end
  return nil
end

M.get_previous_request = function(requests)
  local cursor_pos = vim.api.nvim_win_get_cursor(0) -- {line, col}
  local cursor_line = cursor_pos[1]
  for i, request in ipairs(requests) do
    if cursor_line >= request.start_line and cursor_line <= request.end_line then
      if i > 1 then
        return requests[i - 1]
      end
    end
  end
  return nil
end

M.get_next_request = function(requests)
  local cursor_pos = vim.api.nvim_win_get_cursor(0) -- {line, col}
  local cursor_line = cursor_pos[1]
  for i, request in ipairs(requests) do
    if cursor_line >= request.start_line and cursor_line <= request.end_line then
      if i < #requests then
        return requests[i + 1]
      end
    end
  end
  return nil
end

-- extend the document_variables with the variables defined in the request
-- via the # @file-to-variable variable_name file_path metadata syntax
---@param document_variables table|nil
---@param request Request
---@return table
local function extend_document_variables(document_variables, request)
  document_variables = document_variables or {}
  for _, metadata in ipairs(request.metadata) do
    if metadata then
      if metadata.name == "file-to-variable" then
        local kv = vim.split(metadata.value, " ")
        local variable_name = kv[1]
        local file_path = kv[2]
        local is_binary = #kv > 2 and kv[3] == "binary" or false
        file_path = FS.get_file_path(file_path)
        local file_contents = FS.read_file(file_path, is_binary)
        if file_contents then
          document_variables[variable_name] = file_contents
        end
      end
    end
  end
  return document_variables
end

local cleanup_request_files = function()
  FS.delete_file(GLOBALS.HEADERS_FILE)
  FS.delete_file(GLOBALS.BODY_FILE)
  FS.delete_file(GLOBALS.COOKIES_JAR_FILE)
end

---@class ResponseBodyToFile
---@field file string -- The file path to write the response body to
---@field overwrite boolean -- Whether to overwrite the file if it already exists

---@class Scripts
---@field pre_request ScriptData -- Pre-request handler scripts
---@field post_request ScriptData -- Post-request handler scripts

---@class Request
---@field metadata table[] -- Metadata of the request
---@field method string -- The HTTP method of the request
---@field url_raw string -- The raw URL as it appears in the document
---@field url string -- The URL with variables and dynamic variables replaced
---@field headers table -- The headers with variables and dynamic variables replaced
---@field headers_display table -- The headers with variables and dynamic variables replaced and sanitized
---@field headers_raw table -- The headers as they appear in the document
---@field body_raw string|nil -- The raw body as it appears in the document
---@field body_computed string|nil -- The computed body as sent by curl; with variables and dynamic variables replaced
---@field body_display string|nil -- The body with variables and dynamic variables replaced and sanitized
---(e.g. with binary files replaced with a placeholder)
---@field body string|nil -- The body with variables and dynamic variables replaced
---@field environment table -- The environment- and document-variables
---@field cmd table -- The command to execute the request
---@field ft string -- The filetype of the document
---@field http_version string -- The HTTP version of the request
---@field show_icon_line_number string -- The line number to show the icon
---@field scripts Scripts -- The scripts to run before and after the request
---@field redirect_response_body_to_files ResponseBodyToFile[]

---Parse a request and return the request on itself, its headers and body
---@param start_request_linenr number|nil The line number where the request starts
---@return Request|nil -- Table containing the request data or nil if parsing fails
function M.get_basic_request_data(start_request_linenr)
  local res = {
    metadata = {},
    method = "GET",
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
  }

  local req
  if CONFIG:get().treesitter then
    req = TS.get_request_at(start_request_linenr)
  else
    local _, requests = M.get_document()
    req = M.get_request_at(requests, start_request_linenr)
  end

  if req == nil then
    return nil
  end

  res.scripts.pre_request = req.scripts.pre_request
  res.scripts.post_request = req.scripts.post_request
  res.show_icon_line_number = req.show_icon_line_number
  res.headers = req.headers
  res.headers_raw = req.headers_raw
  res.url_raw = req.url
  res.method = req.method
  res.http_version = req.http_version
  res.body_raw = req.body
  res.body_display = req.body_display
  res.metadata = req.metadata
  res.redirect_response_body_to_files = req.redirect_response_body_to_files

  return res
end

---Replace the variables in the URL, headers and body
---@param res Request -- The request object
---@param document_variables table -- The variables defined in the document
---@param env table -- The environment variables
---@param silent boolean -- Whether to suppress not found variable warnings
---@return string, table, string|nil, string|nil -- The URL, headers, body and body_display with variables replaced
local replace_variables_in_url_headers_body = function(res, document_variables, env, silent)
  local url = parse_url(res.url_raw, document_variables, env, silent)
  local headers = parse_headers(res.headers, document_variables, env, silent)
  local body = parse_body(res.body_raw, document_variables, env, silent)
  local body_display = parse_body_display(res.body_display, document_variables, env, silent)
  return url, headers, body, body_display
end

---Parse a request and return the request on itself, its headers and body
---@param start_request_linenr number|nil The line number where the request starts
---@return Request|nil -- Table containing the request data or nil if parsing fails
M.parse = function(start_request_linenr)
  local res = M.get_basic_request_data(start_request_linenr)

  if res == nil then
    return nil
  end

  local has_pre_request_scripts = #res.scripts.pre_request.inline > 0 or #res.scripts.pre_request.files > 0

  local document_variables
  if CONFIG:get().treesitter then
    document_variables = TS.get_document_variables()
  else
    document_variables = M.get_document()
  end

  DB.update().previous_request = DB.find_unique("current_request")

  local env = ENV_PARSER.get_env()

  document_variables = extend_document_variables(document_variables, res)
  res.environment = vim.tbl_extend("force", env, document_variables)

  -- INFO: if has_pre_request_script:
  -- silently replace the variables in the URL, headers and body, otherwise warn the user
  -- for non existing variables
  res.url, res.headers, res.body, res.body_display =
    replace_variables_in_url_headers_body(res, document_variables, env, has_pre_request_scripts)

  res.headers_display = vim.deepcopy(res.headers)

  -- Merge headers from the $shared environment if it does not exist in the request
  -- this ensures that you can always override the headers in the request
  if DB.find_unique("http_client_env_shared") then
    local default_headers = DB.find_unique("http_client_env_shared")["$default_headers"]
    if default_headers then
      for key, value in pairs(default_headers) do
        if res.headers[key] == nil then
          res.headers[key] = value
        end
      end
    end
  end

  local is_graphql = PARSER_UTILS.contains_meta_tag(res, "graphql")
    or PARSER_UTILS.contains_header(res.headers, "x-request-type", "graphql")
  if res.body ~= nil then
    if is_graphql then
      local gql_json = GRAPHQL_PARSER.get_json(res.body)
      if gql_json then
        res.body_computed = gql_json
      end
    else
      res.body_computed = res.body
    end
  end
  if CONFIG.get().treesitter then
    -- treesitter parser handles graphql requests before this point
    is_graphql = false
  end

  FS.write_file(GLOBALS.REQUEST_FILE, vim.fn.json_encode(res), false)
  -- PERF: We only want to run the scripts if they exist
  -- Also we don't want to re-run the environment replace_variables_in_url_headers_body
  -- if we don't actually have any scripts to run that could have changed the environment
  if has_pre_request_scripts then
    -- INFO:
    -- This runs a client and request script that can be used to magic things
    -- See: https://www.jetbrains.com/help/idea/http-response-reference.html
    M.scripts.javascript.run("pre_request", res.scripts.pre_request)
    -- INFO: now replace the variables in the URL, headers and body again,
    -- because user scripts could have changed them,
    -- but this time also warn the user if a variable is not found
    env = ENV_PARSER.get_env()
    res.url, res.headers, res.body, res.body_display =
      replace_variables_in_url_headers_body(res, document_variables, env, false)
  end

  -- build the command to execute the request
  table.insert(res.cmd, CONFIG.get().curl_path)
  table.insert(res.cmd, "-s")
  table.insert(res.cmd, "-D")
  table.insert(res.cmd, GLOBALS.HEADERS_FILE)
  table.insert(res.cmd, "-o")
  table.insert(res.cmd, GLOBALS.BODY_FILE)
  table.insert(res.cmd, "-w")
  table.insert(res.cmd, "@" .. CURL_FORMAT_FILE)
  table.insert(res.cmd, "-X")
  table.insert(res.cmd, res.method)

  local content_type_header_name, content_type_header_value = PARSER_UTILS.get_header(res.headers, "content-type")

  if content_type_header_name and content_type_header_value and res.body ~= nil then
    -- check if we are a graphql query
    -- we need this here, because the user could have defined the content-type
    -- as application/json, but the body is a graphql query
    -- This can happen when the user is using http-client.env.json with $shared -> $default_headers.
    if is_graphql then
      local gql_json = GRAPHQL_PARSER.get_json(res.body)
      if gql_json then
        if PARSER_UTILS.contains_meta_tag(res, "write-body-to-temporary-file") then
          local tmp_file = FS.get_temp_file(gql_json)
          if tmp_file ~= nil then
            table.insert(res.cmd, "--data")
            table.insert(res.cmd, "@" .. tmp_file)
            res.headers[content_type_header_name] = "application/json"
          else
            Logger.error("Failed to create a temporary file for the request body")
          end
        else
          table.insert(res.cmd, "--data")
          table.insert(res.cmd, gql_json)
          res.headers[content_type_header_name] = "application/json"
        end
      end
    elseif content_type_header_value:find("^multipart/form%-data") then
      local tmp_file = FS.get_binary_temp_file(res.body)
      if tmp_file ~= nil then
        table.insert(res.cmd, "--data-binary")
        table.insert(res.cmd, "@" .. tmp_file)
      else
        Logger.error("Failed to create a temporary file for the binary request body")
      end
    else
      if PARSER_UTILS.contains_meta_tag(res, "write-body-to-temporary-file") then
        local tmp_file = FS.get_temp_file(res.body)
        if tmp_file ~= nil then
          table.insert(res.cmd, "--data")
          table.insert(res.cmd, "@" .. tmp_file)
        else
          Logger.error("Failed to create a temporary file for the request body")
        end
      else
        table.insert(res.cmd, "--data")
        table.insert(res.cmd, res.body)
      end
    end
  else -- no content type supplied
    -- check if we are a graphql query
    if is_graphql then
      local gql_json = GRAPHQL_PARSER.get_json(res.body)
      if gql_json then
        local tmp_file = FS.get_temp_file(gql_json)
        if tmp_file ~= nil then
          table.insert(res.cmd, "--data")
          table.insert(res.cmd, "@" .. tmp_file)
          res.headers["content-type"] = "application/json"
          res.body_computed = gql_json
        else
          Logger.error("Failed to create a temporary file for the request body")
        end
      end
    end
  end

  local auth_header_name, auth_header_value = PARSER_UTILS.get_header(res.headers, "authorization")

  if auth_header_name and auth_header_value then
    local authtype = auth_header_value:match("^(%w+)%s+.*")
    if authtype == nil then
      authtype = auth_header_value:match("^(%w+)%s*$")
    end

    if authtype ~= nil then
      authtype = authtype:lower()

      if authtype == "ntlm" or authtype == "negotiate" or authtype == "digest" or authtype == "basic" then
        local match, authuser, authpw = auth_header_value:match("^(%w+)%s+([^%s:]+)%s*[:%s]%s*([^%s]+)%s*$")
        if match ~= nil or (authtype == "ntlm" or authtype == "negotiate") then
          table.insert(res.cmd, "--" .. authtype)
          table.insert(res.cmd, "-u")
          table.insert(res.cmd, (authuser or "") .. ":" .. (authpw or ""))
          res.headers[auth_header_name] = nil
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
        table.insert(res.cmd, "--aws-sigv4")
        table.insert(res.cmd, provider)
        table.insert(res.cmd, "-u")
        table.insert(res.cmd, key .. ":" .. secret)
        if token then
          table.insert(res.cmd, "-H")
          table.insert(res.cmd, "x-amz-security-token:" .. token)
        end
        res.headers[auth_header_name] = nil
      end
    end
  end

  local protocol, host, port = res.url:match("^([^:]*)://([^:/]*):([^/]*)")
  if not protocol then
    protocol, host = res.url:match("^([^:]*)://([^:/]*)")
  end
  if protocol == "https" then
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
        table.insert(res.cmd, "--cert")
        table.insert(res.cmd, certificate.cert)
      end
      if certificate.key then
        table.insert(res.cmd, "--key")
        table.insert(res.cmd, certificate.key)
      end
    end
  end

  for key, value in pairs(res.headers) do
    table.insert(res.cmd, "-H")
    table.insert(res.cmd, key .. ":" .. value)
  end
  if res.http_version ~= nil then
    table.insert(res.cmd, "--http" .. res.http_version)
  end
  table.insert(res.cmd, "-A")
  table.insert(res.cmd, "kulala.nvim/" .. GLOBALS.VERSION)
  -- if the user has not specified the no-cookie meta tag,
  -- then use the cookies jar file
  if PARSER_UTILS.contains_meta_tag(res, "no-cookie-jar") == false then
    table.insert(res.cmd, "--cookie-jar")
    table.insert(res.cmd, GLOBALS.COOKIES_JAR_FILE)
  end
  for _, additional_curl_option in pairs(CONFIG.get().additional_curl_options) do
    table.insert(res.cmd, additional_curl_option)
  end
  table.insert(res.cmd, res.url)
  cleanup_request_files()
  DB.update().current_request = res
  -- Save this to global,
  -- so .replay() can be triggered from any buffer or window
  DB.global_update().replay = res
  return res
end

return M
