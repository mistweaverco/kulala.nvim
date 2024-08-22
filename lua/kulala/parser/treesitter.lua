local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")
local STRING_UTILS = require("kulala.utils.string")

local M = {}

local QUERIES = {}
local function init_queries()
  if QUERIES.section then
    return
  end

  QUERIES.section = vim.treesitter.query.parse("http", "(section) @section")
  QUERIES.variable = vim.treesitter.query.parse("http", "(variable_declaration) @variable")
  QUERIES.request = vim.treesitter.query.parse("http", [[
    (comment name: (_) value: (_)) @meta

    (pre_request_script
      (script)? @script.pre.inline
      (path)? @script.pre.file)

    (request
      header: (header)? @header
      body: [
        (external_body) @body.external
        (graphql_body) @body.graphql
      ]?) @request

    (res_handler_script
      (script)? @script.post.inline
      (path)? @script.post.file)
  ]])
end

local function text(node)
  if not node then
    return nil
  end

  local node_text = vim.treesitter.get_node_text(node, 0)
  return STRING_UTILS.trim(node_text)
end

local REQUEST_VISITORS = {
  request = function(req, node, fields)
    local start_line, _, end_line, _ = node:range()
    req.url = fields.url
    req.method = fields.method
    req.http_version = fields.http_version
    req.body = fields.body
    req.start_line = start_line
    req.block_line_count = end_line - start_line
    req.lines_length = end_line - start_line

    req.show_icon_line_number = nil
    local show_icons = CONFIG.get().show_icons
    if show_icons ~= nil then
      if show_icons == "on_request" then
        req.show_icon_line_number = start_line + 1
      elseif show_icons == "above_req" then
        req.show_icon_line_number = start_line
      elseif show_icons == "below_req" then
        req.show_icon_line_number = end_line
      end
    end
  end,

  header = function(req, _, fields)
    req.headers[fields.name:lower()] = fields.value
  end,

  meta = function(req, _, fields)
    table.insert(req.metadata, fields)
  end,

  ["script.pre.inline"] = function(req, _, node)
    local script = text(node):gsub("{%%%s*(.-)%s*%%}", "%1")
    table.insert(req.scripts.pre_request.inline, script)
  end,

  ["script.pre.file"] = function(req, _, fields)
    table.insert(req.scripts.pre_request.files, fields.path)
  end,

  ["script.post.inline"] = function(req, node, _)
    local script = text(node):gsub("{%%%s*(.-)%s*%%}", "%1")
    table.insert(req.scripts.post_request.inline, script)
  end,

  ["script.post.file"] = function(req, _, fields)
    table.insert(req.scripts.post_request.files, fields.path)
  end,

  ["body.external"] = function(req, _, fields)
    local contents = FS.read_file(fields.path)
    if fields.path:match("%.graphql$") or fields.path:match("%.gql$") then
      if req.method == "POST" then
        req.body = string.format('{ "query": %q }', STRING_UTILS.remove_newline(contents))
        req.headers['content-type'] = "application/json"
      else
        local query = STRING_UTILS.url_encode(
          STRING_UTILS.remove_extra_space(
            STRING_UTILS.remove_newline(contents)
          )
        )
        req.url = string.format("%s?query=%s", req.url, query)
        req.body = nil
      end
    else
      req.body = contents
    end
  end,

  ["body.graphql"] = function(req, node, _)
    local json_body = {}

    for child in node:iter_children() do
      if child:type() == "graphql_data" then
        json_body.query = text(child)
      elseif child:type() == "json_body" then
        local variables_str = text(child)
        json_body.variables = vim.fn.json_decode(variables_str)
      end
    end

    if #json_body.query > 0 then
      req.body = vim.fn.json_encode(json_body)
      req.headers['content-type'] = "application/json"
    end
  end,
}

local function get_root_node()
  return vim.treesitter.get_parser(0, "http"):parse()[1]:root()
end

local function get_fields(node)
  local tbl = {}
  for child, field in node:iter_children() do
    if field then
      tbl[field] = text(child)
    end
  end
  return tbl
end

local function parse_request(section_node)
  local req = {
    url = "",
    method = "",
    http_version = "",
    headers = {},
    body = "",
    metadata = {},
    show_icon_line_number = nil,
    redirect_response_body_to_files = {},
    start_line = 0,
    block_line_count = 0,
    lines_length = 0,
    scripts = {
      pre_request = { inline = {}, files = {} },
      post_request = { inline = {}, files = {} },
    },
  }

  for i, node in QUERIES.request:iter_captures(section_node, 0) do
    local capture = QUERIES.request.captures[i]
    local fields = get_fields(node)

    if REQUEST_VISITORS[capture] then
      REQUEST_VISITORS[capture](req, node, fields)
    end
  end

  return req
end

M.get_document_variables = function()
  init_queries()
  local root = get_root_node()
  local vars = {}

  for _, node in QUERIES.variable:iter_captures(root, 0) do
    local fields = get_fields(node)
    vars[fields.name] = fields.value
  end

  return vars
end

M.get_request_at = function(line)
  line = line or vim.fn.line(".")
  init_queries()
  local root = get_root_node()

  for _, section_node in QUERIES.section:iter_captures(root, 0, line, line) do
    return parse_request(section_node)
  end
end

M.get_all_requests = function()
  init_queries()
  local root = get_root_node()

  local requests = {}
  for _, section_node in QUERIES.section:iter_captures(root, 0) do
    local req = parse_request(section_node)
    table.insert(requests, req)
  end

  return requests
end

return M
