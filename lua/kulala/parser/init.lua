local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local DYNAMIC_VARS = require("kulala.parser.dynamic_vars")
local ENV_PARSER = require("kulala.parser.env")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local GLOBAL_STORE = require("kulala.global_store")
local GRAPHQL_PARSER = require("kulala.parser.graphql")
local REQUEST_VARIABLES = require("kulala.parser.request_variables")
local STRING_UTILS = require("kulala.utils.string")
local PLUGIN_TMP_DIR = FS.get_plugin_tmp_dir()
local M = {}

local function contains_meta_tag(request, tag)
  for _, meta in ipairs(request.metadata) do
    if meta.name == tag then
      return true
    end
  end
  return false
end

local function contains_header(headers, header, value)
  for k, v in pairs(headers) do
    if k == header and v == value then
      return true
    end
  end
  return false
end

local function parse_string_variables(str, variables)
  local env = ENV_PARSER.get_env()
  local function replace_placeholder(variable_name)
    local value = ""
    -- If the variable name contains a `$` symbol then try to parse it as a dynamic variable
    if variable_name:find("^%$") then
      local variable_value = DYNAMIC_VARS.read(variable_name)
      if variable_value then
        value = variable_value
      end
    elseif variables[variable_name] then
      value = parse_string_variables(variables[variable_name], variables)
    elseif env[variable_name] then
      value = env[variable_name]
    elseif REQUEST_VARIABLES.parse(variable_name) then
      value = REQUEST_VARIABLES.parse(variable_name)
    else
      value = "{{" .. variable_name .. "}}"
      vim.notify(
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

local function parse_headers(headers, variables)
  local h = {}
  for key, value in pairs(headers) do
    h[key] = parse_string_variables(value, variables)
  end
  return h
end

local function encode_url_params(url)
  local url_parts = vim.split(url, "?")
  url = url_parts[1]
  local query = url_parts[2]
  local query_parts = {}
  if query then
    query_parts = vim.split(query, "&")
  end
  local query_params = ""
  for _, query_part in ipairs(query_parts) do
    local query_param = vim.split(query_part, "=")
    query_params = query_params
        .. "&"
        .. STRING_UTILS.url_encode(query_param[1])
        .. "="
        .. STRING_UTILS.url_encode(query_param[2])
  end
  if query_params ~= "" then
    return url .. "?" .. query_params:sub(2)
  end
  return url
end

local function parse_url(url, variables)
  url = parse_string_variables(url, variables)
  url = encode_url_params(url)
  url = url:gsub('"', "")
  return url
end

local function parse_body(body, variables)
  if body == nil then
    return nil
  end
  return parse_string_variables(body, variables)
end

M.get_document = function()
  local content_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local content = table.concat(content_lines, "\n")
  local variables = {}
  local requests = {}
  local blocks = vim.split(content, "\n###\n", { plain = true, trimempty = false })
  local line_offset = 0
  for _, block in ipairs(blocks) do
    local is_request_line = true
    local is_body_section = false
    local lines = vim.split(block, "\n", { plain = true, trimempty = false })
    local block_line_count = #lines
    local request = {
      headers = {},
      metadata = {},
      body = nil,
      start_line = line_offset + 1,
      block_line_count = block_line_count,
      lines_length = #lines,
      variables = {},
    }
    for _, line in ipairs(lines) do
      line = vim.trim(line)
      if line:sub(1, 1) == "#" then
        -- Metadata (e.g., # @this-is-name this is the value)
        -- See: https://httpyac.github.io/guide/metaData.html
        if line:sub(1, 3) == "# @" then
          local meta_name, meta_value = line:match("^# @([%w+%-]+)%s*(.*)$")
          if meta_name and meta_value then
            table.insert(request.metadata, { name = meta_name, value = meta_value })
          end
        end
        -- It's a comment, skip it
      elseif line == "" and is_body_section == false then
        -- Skip empty lines
        if is_request_line == false then
          is_body_section = true
        end
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
      elseif is_body_section == true and #line > 0 then
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
              (request.headers["content-type"] ~= nil and request.headers["content-type"]:find("^multipart/form%-data"))
              or contains_meta_tag(request, "graphql")
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
      elseif is_request_line == false and line:match("^(.+):%s*(.*)$") then
        -- Header
        -- Headers are defined as `key: value`
        -- The key is case-insensitive
        -- The key can be anything except a colon
        -- The value can be a string or a number
        -- The value can be a variable
        -- The value can be a dynamic variable
        -- variables are defined as `{{variable_name}}`
        -- dynamic variables are defined as `{{$variable_name}}`
        local key, value = line:match("^(.+):%s*(.*)$")
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

M.get_request_at_cursor = function(requests)
  local cursor_pos = vim.api.nvim_win_get_cursor(0) -- {line, col}
  local cursor_line = cursor_pos[1]
  for _, request in ipairs(requests) do
    if cursor_line >= request.start_line and cursor_line <= request.end_line then
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

---Parse a request and return the request on itself, its headers and body
---@return Request Table containing the request data
function M.parse()
  local res = {
    metadata = {},
    method = "GET",
    url = {},
    headers = {},
    body = {},
    cmd = {},
    ft = "text",
  }

  local document_variables, requests = M.get_document()
  local req = M.get_request_at_cursor(requests)

  DB.data.previous_request = DB.data.current_request

  document_variables = extend_document_variables(document_variables, req)

  res.url = parse_url(req.url, document_variables)
  res.method = req.method
  res.http_version = req.http_version
  res.headers = parse_headers(req.headers, document_variables)
  res.body = parse_body(req.body, document_variables)
  res.metadata = req.metadata

  -- We need to append the contents of the file to
  -- the body if it is a POST request,
  -- or to the URL itself if it is a GET request
  if req.body_type == "input" then
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
  if GLOBAL_STORE.get("http_client_env_base") then
    local default_headers = GLOBAL_STORE.get("http_client_env_base")["DEFAULT_HEADERS"]
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
  table.insert(res.cmd, "curl")
  table.insert(res.cmd, "-s")
  table.insert(res.cmd, "-D")
  table.insert(res.cmd, PLUGIN_TMP_DIR .. "/headers.txt")
  table.insert(res.cmd, "-o")
  table.insert(res.cmd, PLUGIN_TMP_DIR .. "/body.txt")
  table.insert(res.cmd, "-X")
  table.insert(res.cmd, res.method)
  if res.headers["content-type"] ~= nil and res.body ~= nil then
    -- check if we are a graphql query
    -- we need this here, because the user could have defined the content-type
    -- as application/json, but the body is a graphql query
    -- This can happen when the user is using http-client.env.json with DEFAULT_HEADERS.
    if contains_meta_tag(req, "graphql") or contains_header(res.headers, "x-request-type", "GraphQL") then
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
    if contains_meta_tag(req, "graphql") or contains_header(res.headers, "x-request-type", "GraphQL") then
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
    local authtype, authuser, authpw = auth_header:match("^(%w+)%s+([^%s:]+)%s*[:%s]%s*([^%s]+)%s*$")

    if authtype == nil then
      authtype = auth_header:match("^(%w+)%s*$")
    end

    if authtype ~= nil then
      authtype = authtype:lower()

      if authtype == "ntlm" or authtype == "negotiate" or authtype == "digest" or authtype == "basic" then
        table.insert(res.cmd, "--" .. authtype)
        table.insert(res.cmd, "-u")
        table.insert(res.cmd, (authuser or "") .. ":" .. (authpw or ""))
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
  for _, additional_curl_option in pairs(CONFIG.get().additional_curl_options) do
    table.insert(res.cmd, additional_curl_option)
  end
  table.insert(res.cmd, res.url)
  if res.headers["accept"] == "application/json" then
    res.ft = "json"
  elseif res.headers["accept"] == "application/xml" then
    res.ft = "xml"
  elseif res.headers["accept"] == "text/html" then
    res.ft = "html"
  end
  FS.delete_file(PLUGIN_TMP_DIR .. "/headers.txt")
  FS.delete_file(PLUGIN_TMP_DIR .. "/body.txt")
  FS.delete_file(PLUGIN_TMP_DIR .. "/ft.txt")
  FS.write_file(PLUGIN_TMP_DIR .. "/ft.txt", res.ft)
  if CONFIG.get().debug then
    FS.write_file(PLUGIN_TMP_DIR .. "/request.txt", table.concat(res.cmd, " "))
  end
  DB.data.current_request = res
  return res
end

return M
