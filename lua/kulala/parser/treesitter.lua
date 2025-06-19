if not pcall(require, "nvim-treesitter") then return nil end

local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")
local STRING_UTILS = require("kulala.utils.string")

local M = {}
local QUERIES = {}

local function init_queries()
  if QUERIES.section ~= nil then return end

  QUERIES.section = vim.treesitter.query.parse("http", "(section (request) @request) @section")
  QUERIES.variable = vim.treesitter.query.parse("http", "(variable_declaration) @variable")

  QUERIES.request = vim.treesitter.query.parse(
    "http",
    [[
    (comment name: (_) value: (_)) @meta

    (pre_request_script
      ((script) @script.pre.inline
        (#offset! @script.pre.inline 0 2 0 -2))?
      (path)? @script.pre.file)

    (request
      header: (header)? @header
      body: [
        (external_body) @body.external
        (graphql_body) @body.graphql
      ]?) @request

    (res_handler_script
      ((script) @script.post.inline
        (#offset! @script.post.inline 0 2 0 -2))?
      (path)? @script.post.file)

    (res_redirect
      path: (path)) @redirect
  ]]
  )
end

local function text(node, metadata)
  if not node then return nil end

  local node_text = vim.treesitter.get_node_text(node, 0, { metadata = metadata })
  return STRING_UTILS.trim(node_text)
end

local REQUEST_VISITORS = {
  request = function(req, args)
    local fields = args.fields
    local start_line, _, end_line, _ = args.node:range()

    req.url = fields.url
    req.method = fields.method
    req.http_version = fields.http_version
    req.body = fields.body
    req.body_display = fields.body
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

  header = function(req, args)
    req.headers[args.fields.name:lower()] = args.fields.value
  end,

  meta = function(req, args)
    table.insert(req.metadata, args.fields)
  end,

  ["script.pre.inline"] = function(req, args)
    table.insert(req.scripts.pre_request.inline, args.text)
  end,

  ["script.pre.file"] = function(req, args)
    table.insert(req.scripts.pre_request.files, args.fields.path)
  end,

  ["script.post.inline"] = function(req, args)
    table.insert(req.scripts.post_request.inline, args.text)
  end,

  ["script.post.file"] = function(req, args)
    table.insert(req.scripts.post_request.files, args.fields.path)
  end,

  ["body.external"] = function(req, args)
    local contents = FS.read_file(args.fields.path)
    local filetype, _ = vim.filetype.match { filename = args.fields.path }
    if filetype == "graphql" then
      if req.method == "POST" then
        req.body = string.format('{ "query": %q }', STRING_UTILS.remove_newline(contents))
        req.headers["content-type"] = "application/json"
      else
        local query = STRING_UTILS.url_encode(STRING_UTILS.remove_extra_space(STRING_UTILS.remove_newline(contents)))
        req.url = string.format("%s?query=%s", req.url, query)
        req.body = nil
      end
    else
      req.body = contents
    end
  end,

  ["body.graphql"] = function(req, args)
    local json_body = {}

    for child in args.node:iter_children() do
      if child:type() == "graphql_data" then
        json_body.query = text(child)
      elseif child:type() == "json_body" then
        local variables_str = text(child)
        json_body.variables = vim.fn.json_decode(variables_str)
      end
    end

    if #json_body.query > 0 then
      req.body = vim.fn.json_encode(json_body)
      req.headers["content-type"] = "application/json"
    end
  end,

  redirect = function(req, args)
    local overwrite = false
    if args.text:match("^>>!") then overwrite = true end

    table.insert(req.redirect_response_body_to_files, {
      file = args.fields.path,
      overwrite = overwrite,
    })
  end,
}

local function get_root_node()
  return vim.treesitter.get_parser(0, "http"):parse()[1]:root()
end

local function get_fields(node)
  local tbl = {}
  for child, field in node:iter_children() do
    if field then tbl[field] = text(child) end
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

  for i, node, metadata in QUERIES.request:iter_captures(section_node, 0) do
    local capture = QUERIES.request.captures[i]

    if REQUEST_VISITORS[capture] then
      REQUEST_VISITORS[capture](req, {
        node = node,
        text = text(node, metadata[i]),
        fields = get_fields(node),
      })
    end
  end

  return req
end

M.get_document_variables = function(root)
  init_queries()
  root = root or get_root_node()
  local vars = {}

  for _, node in QUERIES.variable:iter_captures(root, 0) do
    local fields = get_fields(node)
    vars[fields.name] = fields.value
  end

  return vars
end

M.get_request_at = function(line)
  init_queries()
  line = line or (vim.fn.line(".") - 1)
  local root = get_root_node()

  for i, node in QUERIES.section:iter_captures(root, 0, line, line) do
    if QUERIES.section.captures[i] == "section" then return parse_request(node) end
  end
end

M.get_all_requests = function(root)
  init_queries()
  root = root or get_root_node()
  local requests = {}

  for i, node in QUERIES.section:iter_captures(root, 0) do
    if QUERIES.section.captures[i] == "request" then
      local start_line, _, end_line, _ = node:range()
      table.insert(requests, {
        start_line = start_line,
        end_line = end_line,
        metadata = {},
      })
    end
  end

  return requests
end

M.get_document = function()
  init_queries()
  local root = get_root_node()
  local variables = M.get_document_variables(root)
  local requests = M.get_all_requests(root)
  return variables, requests
end

return M
