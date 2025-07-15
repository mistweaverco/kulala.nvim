local Config = require("kulala.config")
local Formatter = require("kulala.formatter")

local format_opts = Config.options.lsp.formatter
format_opts = type(format_opts) == "table" and format_opts or { sort = { json = true } }

local M = {}

local ts = vim.treesitter
local buf

local function capitalize(str)
  return str:lower():gsub("^%l", string.upper):gsub("%-%l", string.upper)
end

local function trim(str)
  str = str or ""
  str = str:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[ \t]+", " ")
  return str
end

local function get_text(node)
  return trim(ts.get_node_text(node, buf))
end

local function get_fields(node, names)
  if not node then return end

  names = names or { "name", "value" }
  names = type(names) == "string" and { names } or names

  local values = {}
  vim.iter(names):each(function(name)
    local field = node:field(name)
    if not (field and #field > 0) then return end
    table.insert(values, get_text(field[1]))
  end)

  return unpack(values)
end

local function previous_node(node)
  local parent = node:parent()
  if not parent then return end

  local pos = 0
  for i = 0, parent:named_child_count() - 1, 1 do
    if parent:named_child(i) == node then
      pos = i
      break
    end
  end

  if pos > 0 then return parent:named_child(pos - 1) end
end

local format_rules, format_node, format_children

local Document = { sections = {} }
local Section = {
  request_separator = nil,
  comments = {},
  variables = {},
  metadata = {},
  commands = {},
  request = {
    url = "",
    headers = {},
    body = "",
    pre_request_script = {},
    res_handler_script = {},
    formatted = "",
  },
  formatted = "",
}

local function current_section()
  if #Document.sections == 0 then table.insert(Document.sections, vim.deepcopy(Section)) end
  return Document.sections[#Document.sections]
end

function format_children(node)
  if node:child_count() == 0 then return end

  for i = 0, node:named_child_count() - 1 do
    format_node(node:named_child(i))
  end
end

function format_node(node)
  local node_type = node:type()
  local rule = format_rules[node_type]

  if rule then
    return rule(node)
  elseif node:child_count() > 0 then
    format_children(node)
  else
    return get_text(node)
  end
end

---@param node_type string previous node type
local function insert_comments(node_type)
  local formatted = current_section().formatted

  vim.iter(current_section().comments):each(function(comment)
    if comment[1] == node_type then
      local formatted_comment = "# " .. comment[2]:gsub("^#%s*", "")
      current_section().formatted = current_section().formatted .. formatted_comment .. "\n"
    end
  end)

  if current_section().formatted == formatted then return end
  current_section().formatted = current_section().formatted .. "\n"
end

---@param condition any
---@param content string
---@param node_type string - node_type
local function insert_formatted(condition, content, node_type)
  if not condition then return end
  current_section().formatted = current_section().formatted .. content .. "\n\n"
  insert_comments(node_type)
end

format_rules = {
  ["document"] = function(node)
    format_children(node)

    local formatted = vim
      .iter(Document.sections)
      :fold("", function(acc, section)
        return acc .. section.formatted .. "\n\n\n"
      end)
      :gsub("\n*$", "")

    Document.formatted = formatted
    return formatted, Document
  end,

  ["section"] = function(node)
    table.insert(Document.sections, vim.deepcopy(Section))
    local section = current_section()

    format_children(node)

    insert_comments("none")

    section.request_separator = not section.request_separator and #Document.sections > 1 and "###"
      or section.request_separator
    insert_formatted(section.request_separator, section.request_separator, "request_separator")

    insert_formatted(#section.variables > 0, table.concat(section.variables, "\n"), "variable_declaration")
    insert_formatted(#section.commands > 0, table.concat(section.commands, "\n"), "command")
    insert_formatted(#section.metadata > 0, table.concat(section.metadata, "\n"), "metadata")
    insert_formatted(#section.request.formatted > 0, section.request.formatted, "request")

    section.formatted = section.formatted:gsub("\n*$", "")
    if section.formatted == "" then table.remove(Document.sections) end

    return section.formatted
  end,

  ["comment"] = function(node)
    local comment = get_text(node)
    local comments = current_section().comments

    local previous = previous_node(node)
    previous = previous and previous:type() or "none"
    previous = previous == "comment" and comments[#comments][1] or previous

    table.insert(current_section().comments, { previous, comment })
    return comment
  end,

  ["request_separator"] = function(node)
    local name = get_fields(node, "value") or ""

    local request_separator = "###"
    request_separator = name and (request_separator .. " " .. name) or name

    current_section().request_separator = request_separator
    return request_separator
  end,

  ["variable_declaration"] = function(node)
    local name, value = get_fields(node)
    local variable_declaration = ("@%s = %s"):format(name or "", value or "")

    table.insert(current_section().variables, variable_declaration)
    _ = format_opts.sort.variables and table.sort(current_section().variables)

    return variable_declaration
  end,

  ["variable_declaration_inline"] = function(node)
    local vars = node:field("variable")
    if not (vars and #vars > 0) then return end

    return vim
      .iter(vars)
      :map(function(var)
        local var_name, var_value = get_fields(var)
        return ("@%s=%s"):format(var_name, var_value)
      end)
      :join(", ")
  end,

  ["metadata"] = function(node)
    local name, value = get_fields(node)
    local str = value and "# @%s %s" or "# @%s"
    local metadata = str:format(name, value)

    table.insert(current_section().metadata, metadata)
    _ = format_opts.sort.metadata and table.sort(current_section().metadata)

    return metadata
  end,

  ["command"] = function(node)
    local name, value = get_fields(node)
    local vars = format_rules["variable_declaration_inline"](node)

    local formatted = ("%s %s"):format(name, value or "")
    formatted = vars and formatted .. " (" .. vars .. ")" or formatted

    table.insert(current_section().commands, formatted)
    _ = format_opts.sort.commands and table.sort(current_section().commands)

    return formatted
  end,

  ["request"] = function(node)
    local formatted = {}

    local method = get_fields(node, "method") or "GET"
    local target_url = get_fields(node, "url") or ""
    local http_version = get_fields(node, "version")
      or (method ~= "GRPC" and method ~= "WEBSOCKET" and method ~= "WS" and "HTTP/1.1" or "")

    local request = current_section().request
    request.url = ("%s %s %s"):format(method, target_url, http_version)

    format_children(node)

    _ = #request.pre_request_script > 0
      and table.insert(formatted, table.concat(request.pre_request_script, "\n\n") .. "\n")

    _ = #request.url > 0 and table.insert(formatted, request.url)

    _ = #request.headers > 0 and table.insert(formatted, table.concat(request.headers, "\n"))
    _ = #request.body > 0 and table.insert(formatted, "\n" .. request.body)
    _ = #request.res_handler_script > 0
      and table.insert(formatted, "\n" .. table.concat(request.res_handler_script, "\n\n"))

    current_section().request.formatted = table.concat(formatted, "\n")
    return current_section().request.formatted
  end,

  ["header"] = function(node)
    local name, value = get_fields(node)
    local header = ("%s: %s"):format(capitalize(name), value or "")

    table.insert(current_section().request.headers, header)
    return header
  end,

  ["raw_body"] = function(node)
    local body = get_text(node)
    current_section().request.body = body
    return body
  end,

  ["multipart_form_data"] = function(node)
    local body = get_text(node)
    current_section().request.body = body
    return body
  end,

  ["xml_body"] = function(node)
    local body = get_text(node)
    local formatted = Formatter.xml(body) or body

    current_section().request.body = formatted:gsub("\n*$", "")
    return formatted
  end,

  ["json_body"] = function(node)
    local json = get_text(node)
    local formatted = Formatter.json(json, { sort = format_opts.sort.json }) or json

    current_section().request.body = formatted:gsub("\n*$", "")
    return formatted
  end,

  ["graphql_body"] = function(node)
    local body = get_text(node)
    local formatted = Formatter.graphql(body, { sort = format_opts.sort.json }) or body

    current_section().request.body = formatted:gsub("\n*$", "")
    return formatted
  end,

  ["external_body"] = function(node)
    local formatted = get_text(node)

    current_section().request.body = formatted
    return formatted
  end,

  ["pre_request_script"] = function(node)
    local script = get_text(node)
    script = script:gsub("\n", "\n  "):gsub("\n  %%}", "\n%%}")

    table.insert(current_section().request.pre_request_script, script)
    return script
  end,

  ["res_handler_script"] = function(node)
    local script = get_text(node)
    script = script:gsub("\n", "\n  "):gsub("\n  %%}", "\n%%}")

    table.insert(current_section().request.res_handler_script, script)
    return script
  end,
}

local function get_nodes_in_range(line_s, line_e, node)
  local function contains(_node)
    local start_row, _, end_row, _ = _node:range()
    return start_row >= line_s and end_row <= line_e + 1
  end

  node = node or ts.get_node { bufnr = buf, pos = { line_s, 0 } }

  local parent = node:parent()
  if parent and contains(parent) then return get_nodes_in_range(line_s, line_e, parent) end

  node = parent or node
  local nodes = {}

  for i = 0, node:named_child_count() - 1 do
    local child = node:named_child(i)
    if contains(child) then table.insert(nodes, child) end
  end

  return nodes
end

local function make_text_edit(text, ls, cs, le, ce)
  return {
    range = {
      ["end"] = { character = ce, line = le },
      start = { character = cs, line = ls },
    },
    newText = text,
  }
end

M.format = function(buffer, params)
  params = params or {}
  buf = buffer or vim.api.nvim_get_current_buf()

  local diag = vim.iter(vim.diagnostic.get(buf) or {}):find(function(d)
    return d.type == "treesitter"
  end)

  if diag and vim.fn.confirm("Document contains errors.  Do you still want to format it?", "&Yes\n&No", 2) ~= 1 then
    return
  end

  local lang = "kulala_http"
  local tree = ts.get_parser(buf, lang):parse()[1]

  Document.sections = {}

  if not params.range then
    local formatted, document = format_rules["document"](tree:root())
    return { make_text_edit(formatted, tree:root():range()) }, document
  end

  local line_s = params.range and params.range.start.line or 0
  local line_e = params.range and params.range["end"].line or vim.api.nvim_buf_line_count(buffer) - 1

  local nodes = get_nodes_in_range(line_s, line_e)

  local result = vim.iter(nodes):fold({}, function(acc, node)
    local formatted = format_node(node) .. "\n"
    table.insert(acc, make_text_edit(formatted, node:range()))
    return acc
  end)

  return result, Document
end

return M
