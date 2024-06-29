local FS = require("kulala.utils.fs")
local CONFIG = require("kulala.config")
local DYNAMIC_VARS = require("kulala.parser.dynamic_vars")
local STRING_UTILS = require("kulala.utils.string")
local ENV_PARSER = require("kulala.parser.env")
local ENV = ENV_PARSER.get_env()
local CFG = CONFIG.get_config()
local PLUGIN_TMP_DIR = FS.get_plugin_tmp_dir()
local M = {}

local function parse_string_variables(str, variables)
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
    elseif ENV[variable_name] then
      value = ENV[variable_name]
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
      local env_var = ENV[variable_name]
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

---Recursively look behind `node` until `query` node type is found
---@param node TSNode|nil Tree-sitter node, defaults to the node at the cursor position if not passed
---@param query string The tree-sitter node type that we are looking for
---@return TSNode|nil
local function look_behind_until(node, query)
  node = node or get_node_at_cursor()

  -- There are no more nodes behind the `document` one
  ---@diagnostic disable-next-line need-check-nil
  if node:type() == "document" then
    ---@diagnostic disable-next-line need-check-nil
    vim.notify("Current node is document, which does not have any parent nodes, returning it instead")
    return node
  end

  ---@diagnostic disable-next-line need-check-nil
  local parent = assert(node:parent())
  if parent:type() ~= query then
    return look_behind_until(parent, query)
  end

  return parent
end

---Traverse a request tree-sitter node and retrieve all its children nodes
---@param req_node TSNode Tree-sitter request node
---@return NodesList
local function traverse_request(req_node)
  local child_nodes = {}
  for child, _ in req_node:iter_children() do
    local child_type = child:type()
    if child_type ~= "header" then
      child_nodes[child_type] = child
    end
  end
  return child_nodes
end

---Traverse a request tree-sitter node and retrieve all its children header nodes
---@param req_node TSNode Tree-sitter request node
---@return NodesList An array-like table containing the request header nodes
local function traverse_headers(req_node)
  local headers = {}
  for child, _ in req_node:iter_children() do
    local child_type = child:type()
    if child_type == "header" then
      table.insert(headers, child)
    end
  end
  return headers
end

---Traverse the document tree-sitter node and retrieve all the `variable_declaration` nodes
---@param document_node TSNode Tree-sitter document node
---@return Variables
local function traverse_variables(document_node)
  local variables = {}
  for child, _ in document_node:iter_children() do
    local child_type = child:type()
    if child_type == "variable_declaration" then
      local var_name = assert(get_node_text(child:field("name")[1], 0))
      local var_value = child:field("value")[1]
      local var_type = var_value:type()
      variables[var_name] = {
        type_ = var_type,
        value = assert(get_node_text(var_value, 0)),
      }
    end
  end
  return variables
end

---Parse request headers tree-sitter nodes
---@param header_nodes NodesList Tree-sitter nodes
---@param variables Variables HTTP document variables list
---@return table A table containing the headers in a key-value style
local function parse_headers(header_nodes, variables)
  local headers = {}
  for _, header_node in ipairs(header_nodes) do
    local header_name = assert(get_node_text(header_node:field("name")[1], 0))
    header_name = header_name:lower()
    -- everything after the first colon
    -- fixes various tree-sitter bugs
    local header_string = get_node_text(header_node, 0)
    local header_value = header_string:sub(header_string:find(":") + 1)
    header_value = STRING_UTILS.trim(header_value)
    headers[header_name] = parse_string_variables(header_value, variables)
  end

  return headers
end

local function parse_url(url)
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

---Parse a request tree-sitter node
---@param children_nodes NodesList Tree-sitter nodes
---@param variables Variables HTTP document variables list
---@return table A table containing the request target `url` and `method` to be used
local function parse_request(children_nodes, variables)
  local request = {}
  for node_type, node in pairs(children_nodes) do
    if node_type == "method" then
      request.method = assert(get_node_text(node, 0))
    elseif node_type == "target_url" then
      request.url = assert(get_node_text(node, 0))
    elseif node_type == "http_version" then
      local http_version = assert(get_node_text(node, 0))
      request.http_version = http_version:gsub("HTTP/", "")
    elseif node_type == "request" then
      request = parse_request(traverse_request(node), variables)
    end
  end

  -- Parse the request nodes again as a single string converted into a new AST Tree to expand the variables
  local request_text = request.method .. " " .. request.url .. "\n"
  local request_tree = vim.treesitter.get_string_parser(request_text, "http"):parse()[1]
  request.url = parse_string_variables(request.url, variables)
  request.url = parse_url(request.url)
  ---@cast variable_value string
  request.url = request.url:gsub('"', "")
  return request
end

---Recursively traverse a body table and expand all the variables
---@param tbl table Request body
---@return table
local function traverse_body(tbl, variables)
  ---Expand a variable in the given string
  ---@param str string String where the variables are going to be expanded
  ---@param vars Variables HTTP document variables list
  ---@return string|number|boolean
  local function expand_variable(str, vars)
    local variable_name = str:gsub("{{[%s]?", ""):gsub("[%s]?}}", ""):match(".*")
    local variable_value

    -- If the variable name contains a `$` symbol then try to parse it as a dynamic variable
    if variable_name:find("^%$") then
      variable_value = DYNAMIC_VARS.read(variable_name)
      if variable_value then
        return variable_value
      end
    end

    local variable = vars[variable_name]
    -- If the variable was not found in the document then fallback to the shell environment
    if not variable then
      ---@diagnostic disable-next-line need-check-nil
      vim.notify(
        "The variable '" .. variable_name .. "' was not found in the document, falling back to the environment ..."
      )
      local env_var = ENV[variable_name]
      if not env_var then
        ---@diagnostic disable-next-line need-check-nil
        vim.notify(
          "The variable '"
            .. variable_name
            .. "' was not found in the document or in the environment. Returning the string as received ..."
        )
        return str
      end
      variable_value = env_var
    else
      variable_value = variable.value
      if variable.type_ == "string" then
        ---@cast variable_value string
        variable_value = variable_value:gsub('"', "")
      end
    end
    ---@cast variable_value string|number|boolean
    return variable_value
  end

  for k, v in pairs(tbl) do
    if type(v) == "table" then
      traverse_body(v, variables)
    end

    if type(k) == "string" and k:find("{{[%s]?.*[%s]?}}") then
      local variable_value = expand_variable(k, variables)
      local key_value = tbl[k]
      tbl[k] = nil
      tbl[variable_value] = key_value
    end
    if type(v) == "string" and v:find("{{[%s]?.*[%s]?}}") then
      local variable_value = expand_variable(v, variables)
      tbl[k] = variable_value
    end
  end

  return tbl
end

---Parse a request tree-sitter node body
---@param children_nodes NodesList Tree-sitter nodes
---@param variables Variables HTTP document variables list
---@return table Decoded body table
local function parse_body(children_nodes, variables)
  local body = {}

  for node_type, node in pairs(children_nodes) do
    if node_type == "json_body" then
      local json_body_text = assert(get_node_text(node, 0))
      local json_body = vim.json.decode(json_body_text)
      body = traverse_body(json_body, variables)
      -- This is some metadata to be used later on
      body.__TYPE = "json"
    elseif node_type == "xml_body" then
      vim.notify("XML body is not supported yet")
    elseif node_type == "external_body" then
      -- < @ (identifier) (file_path name: (path))
      -- 0 1      2                 3
      if node:child_count() > 2 then
        body.name = assert(get_node_text(node:child(2), 0))
      end
      body.path = assert(get_node_text(node:field("file_path")[1], 0))
      -- This is some metadata to be used later on
      body.__TYPE = "external_file"
    elseif node_type == "form_data" then
      local names = node:field("name")
      local values = node:field("value")
      if vim.tbl_count(names) > 1 then
        for idx, name in ipairs(names) do
          ---@type string|number|boolean
          local value = assert(get_node_text(values[idx], 0)):gsub('"', "")
          body[assert(get_node_text(name, 0))] = value
        end
      else
        ---@type string|number|boolean
        local value = assert(get_node_text(values[1], 0)):gsub('"', "")
        body[assert(get_node_text(names[1], 0))] = value
      end
      -- This is some metadata to be used later on
      body.__TYPE = "form"
    end
  end

  return body
end

---Get the request node from the cursor position
---@return TSNode|nil Tree-sitter node
---@return string|nil Node type
local function get_request_node()
  local node = get_node_at_cursor()
  return look_behind_until(node, "request")
end

---Parse a request and return the request on itself, its headers and body
---@return Request Table containing the request data
function M.parse()
  local res = {
    type = "rest",
    request = {},
    headers = {},
    body = {},
    script = "",
    cmd = {},
    ft = nil,
  }
  local document_variables = {}
  local req_node = get_request_node()
  local document_node = look_behind_until(nil, "document")

  local request_children_nodes = traverse_request(req_node)
  local request_header_nodes = traverse_headers(req_node)

  ---@cast document_node TSNode
  local document_variables = traverse_variables(document_node)

  res.request = parse_request(request_children_nodes, document_variables)
  res.headers = parse_headers(request_header_nodes, document_variables)
  res.body = parse_body(request_children_nodes, document_variables)

  -- We need to append the contents of the file to
  -- the body if it is a POST request,
  -- or to the URL itself if it is a GET request
  if res.body.path ~= nil then
    if res.body.path:match("%.graphql$") or res.body.path:match("%.gql$") then
      res.type = "graphql"
      local graphql_file = io.open(res.body.path, "r")
      local graphql_query = graphql_file:read("*a")
      graphql_file:close()
      if res.request.method == "POST" then
        res.body = "{ \"query\": \"" .. graphql_query .."\" }"
      else
        graphql_query = STRING_UTILS.url_encode(STRING_UTILS.remove_extra_space(STRING_UTILS.remove_newline(graphql_query)))
        res.graphql_query = STRING_UTILS.url_decode(graphql_query)
        res.request.url = res.request.url .. "?query=" .. graphql_query
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
  table.insert(res.cmd, res.request.method)
  if type(res.body) == "string" then
    table.insert(res.cmd, "--data-raw")
    table.insert(res.cmd, res.body)
  elseif res.body.__TYPE == "json" then
    res.body.__TYPE = nil
    table.insert(res.cmd, "--data-raw")
    table.insert(res.cmd, vim.json.encode(res.body))
  elseif res.body.__TYPE == "form" then
    res.body.__TYPE = nil
    for key, value in pairs(res.body) do
      table.insert(res.cmd, "--data-raw")
      table.insert(res.cmd, key .."=".. value)
    end
  end
  for key, value in pairs(res.headers) do
    table.insert(res.cmd, "-H")
    table.insert(res.cmd, key ..":".. value)
  end
  if res.request.http_version ~= nil then
    table.insert(res.cmd, "--http" .. res.request.http_version)
  end
  table.insert(res.cmd, "-A")
  table.insert(res.cmd, "kulala.nvim/alpha")
  table.insert(res.cmd, res.request.url)
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
  return res
end

return M
