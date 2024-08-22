local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")

local M = {}

local function get_node_text(node)
  if not node then
    return nil
  end

  local text = vim.treesitter.get_node_text(node, 0)
  return text:gsub("^%s*(.-)%s*$", "%1")
end

local function get_fields(node)
  local tbl = {}
  for child, field in node:iter_children() do
    if field then
      tbl[field] = get_node_text(child)
    end
  end
  return tbl
end

M.get_document_variables = function(root)
  local vars = {}

  local query = vim.treesitter.query.parse("http", "(variable_declaration) @variable")
  for _, node in query:iter_captures(root, 0) do
    local fields = get_fields(node)
    vars[fields.name] = fields.value
  end

  return vars
end

local function new_request()
  return {
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
end

M.get_request_at_cursor = function(root)
  local pos_node = vim.treesitter.get_node()
  if not pos_node then
    return nil
  end

  local section_query = vim.treesitter.query.parse("http", "(section) @section")
  local request_query = vim.treesitter.query.parse("http", [[
    (comment name: (_) value: (_)) @meta

    (pre_request_script
      (script)? @script.pre.inline
      (path)? @script.pre.file)

    (request
      header: (header)? @header
      body: (external_body)? @body.external) @request

    (res_handler_script
      (script)? @script.post.inline
      (path)? @script.post.file)
  ]])

  local start_pos, _, end_pos, _ = pos_node:range()
  for _, section_node in section_query:iter_captures(root, 0, start_pos, end_pos+1) do
    local req = new_request()

    for i, node in request_query:iter_captures(section_node, 0) do
      local capture = request_query.captures[i]
      local fields = get_fields(node)

      if capture == "request" then
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

      elseif capture == "header" then
        req.headers[fields.name] = fields.value

      elseif capture == "meta" then
        table.insert(req.metadata, fields)

      elseif capture == "script.pre.inline" then
        local script = get_node_text(node):gsub("{%%%s*(.-)%s*%%}", "%1")
        table.insert(req.scripts.pre_request.inline, script)

      elseif capture == "script.pre.file" then
        local file = get_node_text(node)
        table.insert(req.scripts.pre_request.files, file)

      elseif capture == "script.post.inline" then
        local script = get_node_text(node):gsub("{%%%s*(.-)%s*%%}", "%1")
        table.insert(req.scripts.post_request.inline, script)

      elseif capture == "script.post.file" then
        local file = get_node_text(node)
        table.insert(req.scripts.post_request.files, file)

      elseif capture == "body.external" then
        req.body = FS.read_file(fields.path)
      end
    end

    return req
  end
end

return M
