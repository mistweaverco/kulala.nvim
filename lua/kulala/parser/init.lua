local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local DYNAMIC_VARS = require("kulala.parser.dynamic_vars")
local STRING_UTILS = require("kulala.utils.string")
local TABLE_UTILS = require("kulala.utils.table")
local ENV_PARSER = require("kulala.parser.env")
local CFG = CONFIG.get_config()
local PLUGIN_TMP_DIR = FS.get_plugin_tmp_dir()
local CLIENT_PIPE = require("kulala.client_pipe")
local M = {}

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
      value = variables[variable_name].value
    elseif env[variable_name] then
      value = env[variable_name]
    else
      value = "{{" .. variable_name .. "}}"
      vim.notify(
        "The variable '"
          .. variable_name
          .. "' was not found in the document or in the environment. Returning the string as received ..."
      )
    end
    if type(value) == "string" then
      ---@cast variable_value string
      value = value:gsub('"', "")
    end
    return value
  end
  local result = str:gsub("{{(.-)}}", replace_placeholder)
  return result
end

---Small wrapper around `vim.treesitter.get_node_text`
---@see vim.treesitter.get_node_text
---@param node TSNode Tree-sitter node
---@param source integer|string Buffer or string from which the `node` is extracted
---@return string|nil
local function get_node_text(node, source)
  source = source or 0
  return vim.treesitter.get_node_text(node, source)
end

---Get a tree-sitter node at the cursor position
---@return TSNode|nil Tree-sitter node
---@return string|nil Node type
local function get_node_at_cursor()
  local node = assert(vim.treesitter.get_node())
  return node, node:type()
end

---Parse all the variable nodes in the given node and expand them to their values
---@param node TSNode Tree-sitter node
---@param tree string The text where variables should be looked for
---@param text string The text where variables should be expanded
---@param variables Variables HTTP document variables list
---@return string|nil The given `text` with expanded variables
local function parse_variables(node, tree, text, variables)
  local env = ENV_PARSER.get_env()
  local variable_query = vim.treesitter.query.parse("http", "(variable name: (_) @name)")
  ---@diagnostic disable-next-line missing-parameter
  for _, nod, _ in variable_query:iter_captures(node:root(), tree) do
    local variable_name = assert(get_node_text(nod, tree))
    local variable_value

    -- If the variable name contains a `$` symbol then try to parse it as a dynamic variable
    if variable_name:find("^%$") then
      variable_value = DYNAMIC_VARS.read(variable_name)
      if variable_value then
        return variable_value
      end
    end

    local variable = variables[variable_name]
    -- If the variable was not found in the document then fallback to the shell environment
    if not variable then
      ---@diagnostic disable-next-line need-check-nil
      vim.notify(
        "The variable '" .. variable_name .. "' was not found in the document, falling back to the environment ..."
      )
      local env_var = env[variable_name]
      if not env_var then
        ---@diagnostic disable-next-line need-check-nil
        vim.notify(
          "The variable '"
            .. variable_name
            .. "' was not found in the document or in the environment. Returning the string as received ..."
        )
        return text
      end
      variable_value = env_var
    else
      variable_value = variable.value
      if variable.type_ == "string" then
        ---@cast variable_value string
        variable_value = variable_value:gsub('"', "")
      end
    end
    text = text:gsub("{{[%s]?" .. variable_name .. "[%s]?}}", variable_value)
  end
  return text
end

local function parse_headers(headers, variables)
  local h = {}
  for key, value in pairs(headers) do
    h[key] = parse_string_variables(value, variables)
  end
  return h
end

local function encode_url_params(url)
  local url_parts = {}
  local url_parts = vim.split(url, "?")
  local url = url_parts[1]
  local query = url_parts[2]
  local query_parts = {}
  if query then
    query_parts = vim.split(query, "&")
  end
  local query_params = ""
  for _, query_part in ipairs(query_parts) do
    local query_param = vim.split(query_part, "=")
    query_params = query_params .. "&" .. STRING_UTILS.url_encode(query_param[1]) .. "=" .. STRING_UTILS.url_encode(query_param[2])
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

local function get_document()
  local content_lines = content or vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local content = table.concat(content_lines, "\n")
  local variables = {}
  local requests = {}
  local blocks = vim.split(content, "###", true)
  local line_offset = 0
  for _, block in ipairs(blocks) do
    local lines = vim.split(block, "\n", true)
    local request = {headers = {}, body = nil, start_line = line_offset + 1}
    local block_line_count = #lines
    for _, line in ipairs(lines) do
      line = vim.trim(line)
      if line:sub(1, 1) == "#" then
        -- It's a comment, skip it
      elseif line == "" then
        -- Skip empty lines
      elseif line:match("^@%w+") then
        -- Variable
        -- Variables are defined as `@variable_name=value`
        -- The value can be a string, a number or boolean
        local variable_name, variable_value = line:match("^%@(%w+)%s*=%s*(.*)$")
        -- remove the @ symbol from the variable name
        variable_name = variable_name:sub(2)
        if variable_name and variable_value then
          variables[variable_name] = variable_value
        end
      elseif line:match("^%b{}$") then
        -- JSON body
        request.body = line
      elseif line:match("^%b[]$") then
        -- Form body
        request.body = line
      elseif line:match("^%b<>$") then
        -- Input body
        request.body_type = "input"
        request.body_path = line:sub(2, -2)
        request.body = line
      elseif line:match("^(%w+):%s*(.*)$") then
        -- Header
        -- Headers are defined as `key: value`
        -- The key is case-insensitive
        -- The value can be a string or a number
        -- The value can be a variable
        -- The value can be a dynamic variable
        -- variables are defined as `{{variable_name}}`
        -- dynamic variables are defined as `{{$variable_name}}`
        local key, value = line:match("^(.-):%s*(.*)$")
        if key and value then
          request.headers[key:lower()] = value
        end
      else
        -- Request line (e.g., GET http://example.com HTTP/1.1)
        -- Split the line into method, URL and HTTP version
        -- HTTP Version is optional
        local parts = vim.split(line, " ", true)
        request.method = parts[1]
        request.url = parts[2]
        if parts[3] then
          request.http_version = parts[3]:gsub("HTTP/", "")
        end
      end
    end
    request.end_line = line_offset + block_line_count
    line_offset = line_offset + block_line_count + 1 -- +1 for the '###' separator line
    table.insert(requests, request)
  end
  return variables, requests
end

local function get_request_at_cursor(requests)
  local cursor_pos = vim.api.nvim_win_get_cursor(0) -- {line, col}
  local cursor_line = cursor_pos[1]
  for _, request in ipairs(requests) do
    if cursor_line >= request.start_line and cursor_line <= request.end_line then
      return request
    end
  end
  return nil
end

---Parse a request and return the request on itself, its headers and body
---@return Request Table containing the request data
function M.parse()
  local res = {
    method = "GET",
    url = {},
    headers = {},
    body = {},
    cmd = {},
    client_pipe = nil,
    ft = "text",
  }

  local document_variables, requests = get_document()
  local req = get_request_at_cursor(requests)

  res.url = parse_url(req.url, document_variables)
  res.method = req.method
  res.http_version = req.http_version
  res.headers = parse_headers(req.headers, document_variables)
  res.body = parse_body(req.body, document_variables)

  -- We need to append the contents of the file to
  -- the body if it is a POST request,
  -- or to the URL itself if it is a GET request
  if req.body_type == "input" then
    if req.body_path:match("%.graphql$") or req.body_path:match("%.gql$") then
      local graphql_file = io.open(req.body_path, "r")
      local graphql_query = graphql_file:read("*a")
      graphql_file:close()
      if res.method == "POST" then
        res.body = "{ \"query\": \"" .. graphql_query .."\" }"
      else
        graphql_query = STRING_UTILS.url_encode(STRING_UTILS.remove_extra_space(STRING_UTILS.remove_newline(graphql_query)))
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

  local client_pipe = nil

  -- build the command to exectute the request
  table.insert(res.cmd, "curl")
  table.insert(res.cmd, "-s")
  table.insert(res.cmd, "-D")
  table.insert(res.cmd, PLUGIN_TMP_DIR .. "/headers.txt")
  table.insert(res.cmd, "-o")
  table.insert(res.cmd, PLUGIN_TMP_DIR .. "/body.txt")
  table.insert(res.cmd, "-X")
  table.insert(res.cmd, res.method)
  if res.headers["content-type"] == "text/plain" then
    table.insert(res.cmd, "--data-raw")
    table.insert(res.cmd, res.body)
  elseif res.headers["content-type"] == "application/json" then
    table.insert(res.cmd, "--data-raw")
    table.insert(res.cmd, vim.json.encode(res.body))
  elseif res.headers["content-type"] == "application/x-www-form-urlencoded" or res.headers["content-type"] == "multipart/form-data" then
    for key, value in pairs(res.body) do
      table.insert(res.cmd, "--data-raw")
      table.insert(res.cmd, key .."=".. value)
    end
  end
  for key, value in pairs(res.headers) do
    -- if key starts with `http-client-` then it is a special header
    if key:find("^http%-client%-") then
      if key == "http-client-pipe" then
        res.client_pipe = value
      end
    else
      table.insert(res.cmd, "-H")
      table.insert(res.cmd, key ..":".. value)
    end
  end
  if res.http_version ~= nil then
    table.insert(res.cmd, "--http" .. res.http_version)
  end
  table.insert(res.cmd, "-A")
  table.insert(res.cmd, "kulala.nvim/".. GLOBALS.VERSION)
  table.insert(res.cmd, res.url)
  if res.headers['accept'] == "application/json" then
    res.ft = "json"
  elseif res.headers['accept'] == "application/xml" then
    res.ft = "xml"
  elseif res.headers['accept'] == "text/html" then
    res.ft = "html"
  end
  FS.write_file(PLUGIN_TMP_DIR .. "/ft.txt", res.ft)
  if CFG.debug then
    FS.write_file(PLUGIN_TMP_DIR .. "/request.txt", table.concat(res.cmd, " "))
  end
  vim.notify(vim.inspect(res))
  return res
end

return M
