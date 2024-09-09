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
local PLUGIN_TMP_DIR = FS.get_plugin_tmp_dir()
local CURL_FORMAT_FILE = FS.get_plugin_path({ "parser", "curl-format.json" })
local Scripts = require("kulala.scripts")
local Logger = require("kulala.logger")
local M = {}

local function parse_string_variables(str, variables, env)
  local function replace_placeholder(variable_name)
    local value = ""
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
      Logger.info(
        "The variable '"
          .. variable_name
          .. "' was not found in the document or in the environment. Returning the string as received ..."
      )
    end
    return value
  end
  local result = str:gsub("{{(.-)}}", replace_placeholder)
  return result
end

local function parse_headers(headers, variables, env)
  local h = {}
  for key, value in pairs(headers) do
    h[key] = parse_string_variables(value, variables, env)
  end
  return h
end

local function encode_url_params(url)
  local anchor = ""
  local index = url:find("#")
  if index then
    anchor = "#" .. STRING_UTILS.url_encode(url:sub(index + 1))
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
        .. STRING_UTILS.url_encode(query_part:sub(1, index - 1))
        .. "="
        .. STRING_UTILS.url_encode(query_part:sub(index + 1))
    else
      query_params = query_params .. "&" .. STRING_UTILS.url_encode(query_part)
    end
  end
  if query_params ~= "" then
    url = url .. "?" .. query_params:sub(2)
  end
  return url .. anchor
end

local function parse_url(url, variables, env)
  url = parse_string_variables(url, variables, env)
  url = encode_url_params(url)
  url = url:gsub('"', "")
  return url
end

local function parse_body(body, variables, env)
  if body == nil then
    return nil
  end
  return parse_string_variables(body, variables, env)
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
    return nil
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
    return nil
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
      metadata = {},
      body = nil,
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
        if request.body == nil then
          request.body = ""
        end
        if line:find("^<") then
          if
            request.headers["content-type"] ~= nil and request.headers["content-type"]:find("^multipart/form%-data")
          then
            request.body = request.body .. line .. "\r\n"
          else
            local file_path = vim.trim(line:sub(2))
            local contents = FS.read_file(file_path)
            if contents then
              request.body = request.body .. contents
            else
              vim.notify("The file '" .. file_path .. "' was not found. Skipping ...", "warn")
            end
          end
        else
          if
            request.headers["content-type"] ~= nil and request.headers["content-type"]:find("^multipart/form%-data")
          then
            request.body = request.body .. line .. "\r\n"
          elseif
            request.headers["content-type"] ~= nil
            and request.headers["content-type"]:find("^application/x%-www%-form%-urlencoded")
          then
            request.body = request.body .. line
          else
            request.body = request.body .. line .. "\r\n"
          end
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
          request.headers[key:lower()] = value
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
    end
    request.end_line = line_offset + block_line_count
    line_offset = request.end_line + 1 -- +1 for the '###' separator line
    table.insert(requests, request)
  end
  return variables, requests
end

M.get_request_at = function(requests, linenr)
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
local function extend_document_variables(document_variables, request)
  for _, metadata in ipairs(request.metadata) do
    if metadata then
      if metadata.name == "file-to-variable" then
        local kv = vim.split(metadata.value, " ")
        local variable_name = kv[1]
        local file_path = kv[2]
        local file_contents = FS.read_file(file_path)
        if file_contents then
          document_variables[variable_name] = file_contents
        end
      end
    end
  end
  return document_variables
end

---@class ResponseBodyToFile
---@field file string -- The file path to write the response body to
---@field overwrite boolean -- Whether to overwrite the file if it already exists

---@class ScriptsItems
---@field inline table -- Inline post-request handler scripts - each element is a line of the script
---@field file table -- File post-request handler scripts - each element is a file path
---
---@class Scripts
---@field pre_request ScriptsItems[] -- Pre-request handler scripts
---@field post_request ScriptsItems[] -- Post-request handler scripts

---@class Request
---@field metadata table
---@field method string
---@field url table
---@field headers table
---@field body table
---@field cmd table
---@field ft string
---@field http_version string
---@field show_icon_line_number string
---@field scripts Scripts
---@field redirect_response_body_to_files ResponseBodyToFile[]

---Parse a request and return the request on itself, its headers and body
---@param start_request_linenr number|nil The line number where the request starts
---@return Request|nil -- Table containing the request data or nil if parsing fails
function M.parse(start_request_linenr)
  local res = {
    metadata = {},
    method = "GET",
    url = {},
    headers = {},
    body = {},
    cmd = {},
    ft = "text",
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

  local req, document_variables
  if CONFIG:get().treesitter then
    document_variables = TS.get_document_variables()
    req = TS.get_request_at(start_request_linenr)
  else
    local requests
    document_variables, requests = M.get_document()
    req = M.get_request_at(requests, start_request_linenr)
  end

  if req == nil then
    return nil
  end

  Scripts.javascript.run("pre_request", req.scripts.pre_request)
  local env = ENV_PARSER.get_env()

  DB.update().previous_request = DB.find_unique("current_request")

  document_variables = extend_document_variables(document_variables, req)

  res.scripts.pre_request = req.scripts.pre_request
  res.scripts.post_request = req.scripts.post_request
  res.show_icon_line_number = req.show_icon_line_number
  res.url = parse_url(req.url, document_variables, env)
  res.method = req.method
  res.http_version = req.http_version
  res.headers = parse_headers(req.headers, document_variables, env)
  res.body = parse_body(req.body, document_variables, env)
  res.metadata = req.metadata
  res.redirect_response_body_to_files = req.redirect_response_body_to_files

  -- We need to append the contents of the file to
  -- the body if it is a POST request,
  -- or to the URL itself if it is a GET request
  if req.body_type == "input" and not CONFIG:get().treesitter then
    if req.body_path:match("%.graphql$") or req.body_path:match("%.gql$") then
      local graphql_file = io.open(req.body_path, "r")
      local graphql_query = graphql_file:read("*a")
      graphql_file:close()
      if res.method == "POST" then
        res.body = '{ "query": "' .. graphql_query .. '" }'
      else
        graphql_query =
          STRING_UTILS.url_encode(STRING_UTILS.remove_extra_space(STRING_UTILS.remove_newline(graphql_query)))
        res.graphql_query = STRING_UTILS.url_decode(graphql_query)
        res.url = res.url .. "?query=" .. graphql_query
      end
    else
      local file = io.open(req.body_path, "r")
      local body = file:read("*a")
      file:close()
      res.body = body
    end
  end

  -- Merge headers from the _base environment if it exists
  if DB.find_unique("http_client_env_base") then
    local default_headers = DB.find_unique("http_client_env_base")["DEFAULT_HEADERS"]
    if default_headers then
      for key, value in pairs(default_headers) do
        key = key:lower()
        if res.headers[key] == nil then
          res.headers[key] = value
        end
      end
    end
  end

  -- build the command to exectute the request
  table.insert(res.cmd, CONFIG.get().curl_path)
  table.insert(res.cmd, "-s")
  table.insert(res.cmd, "-D")
  table.insert(res.cmd, PLUGIN_TMP_DIR .. "/headers.txt")
  table.insert(res.cmd, "-o")
  table.insert(res.cmd, PLUGIN_TMP_DIR .. "/body.txt")
  table.insert(res.cmd, "-w")
  table.insert(res.cmd, "@" .. CURL_FORMAT_FILE)
  table.insert(res.cmd, "-X")
  table.insert(res.cmd, res.method)

  local is_graphql = PARSER_UTILS.contains_meta_tag(req, "graphql")
    or PARSER_UTILS.contains_header(res.headers, "x-request-type", "GraphQL")
  if CONFIG.get().treesitter then
    -- treesitter parser handles graphql requests before this point
    is_graphql = false
  end

  if res.headers["content-type"] ~= nil and res.body ~= nil then
    -- check if we are a graphql query
    -- we need this here, because the user could have defined the content-type
    -- as application/json, but the body is a graphql query
    -- This can happen when the user is using http-client.env.json with DEFAULT_HEADERS.
    if is_graphql then
      local gql_json = GRAPHQL_PARSER.get_json(res.body)
      if gql_json then
        table.insert(res.cmd, "--data")
        table.insert(res.cmd, gql_json)
        res.headers["content-type"] = "application/json"
      end
    elseif res.headers["content-type"]:find("^multipart/form%-data") then
      table.insert(res.cmd, "--data-binary")
      table.insert(res.cmd, res.body)
    else
      table.insert(res.cmd, "--data")
      table.insert(res.cmd, res.body)
    end
  else -- no content type supplied
    -- check if we are a graphql query
    if is_graphql then
      local gql_json = GRAPHQL_PARSER.get_json(res.body)
      if gql_json then
        table.insert(res.cmd, "--data")
        table.insert(res.cmd, gql_json)
        res.headers["content-type"] = "application/json"
      end
    end
  end

  if res.headers["authorization"] then
    local auth_header = res.headers["authorization"]
    local authtype = auth_header:match("^(%w+)%s+.*")
    if authtype == nil then
      authtype = auth_header:match("^(%w+)%s*$")
    end

    if authtype ~= nil then
      authtype = authtype:lower()

      if authtype == "ntlm" or authtype == "negotiate" or authtype == "digest" or authtype == "basic" then
        local match, authuser, authpw = auth_header:match("^(%w+)%s+([^%s:]+)%s*[:%s]%s*([^%s]+)%s*$")
        if match ~= nil or (authtype == "ntlm" or authtype == "negotiate") then
          table.insert(res.cmd, "--" .. authtype)
          table.insert(res.cmd, "-u")
          table.insert(res.cmd, (authuser or "") .. ":" .. (authpw or ""))
          res.headers["authorization"] = nil
        end
      elseif authtype == "aws" then
        local key, secret, optional = auth_header:match("^%w+%s([^%s]+)%s*([^%s]+)[%s$]+(.*)$")
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
        res.headers["authorization"] = nil
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
  if PARSER_UTILS.contains_meta_tag(req, "no-cookie-jar") == false then
    table.insert(res.cmd, "--cookie-jar")
    table.insert(res.cmd, GLOBALS.COOKIES_JAR_FILE)
  end
  for _, additional_curl_option in pairs(CONFIG.get().additional_curl_options) do
    table.insert(res.cmd, additional_curl_option)
  end
  table.insert(res.cmd, res.url)
  -- TODO:
  -- Make a cleanup function that deletes the files
  -- and mayebe sets up other things
  FS.delete_file(GLOBALS.HEADERS_FILE)
  FS.delete_file(GLOBALS.BODY_FILE)
  FS.delete_file(GLOBALS.COOKIES_JAR_FILE)
  if CONFIG.get().debug then
    FS.write_file(PLUGIN_TMP_DIR .. "/request.txt", table.concat(res.cmd, " "), false)
  end
  DB.update().current_request = res
  -- Save this to global,
  -- so .replay() can be triggered from any buffer or window
  DB.global_update().replay = res
  return res
end

return M
