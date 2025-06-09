local Config = require("kulala.config")
local Json = require("kulala.utils.json")

local M = {}

local ts = vim.treesitter
local buf

local function capitalize(str)
  return str:lower():gsub("^%l", string.upper):gsub("%-%l", string.upper)
end

local function trim(str)
  str = str or ""
  str = str:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  return str
end

local function get_text(node)
  return trim(ts.get_node_text(node, buf))
end

local function get_fields(node, names)
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

local format_rules

format_rules = {
  ["document_out"] = function(node)
    --
  end,
  ["request_separator"] = function(node)
    local name = get_fields(node, "value")
    return ("### %s"):format(name)
  end,

  ["variable_declaration"] = function(node)
    local name, value = get_fields(node)
    return ("@%s = %s"):format(name, value)
  end,

  ["metadata"] = function(node)
    local name, value = get_fields(node)
    local str = value and "# @%s %s" or "# @%s"
    return str:format(name, value)
  end,

  ["request"] = function(node)
    local method = get_fields(node, "method") or "GET"
    local target_url = get_fields(node, "url") or ""
    local http_version = get_fields(node, "version") or "HTTP/1.1"

    local headers = vim
      .iter(node:field("header"))
      :map(function(header)
        return format_rules["header"](header)
      end)
      :join("\n")

    local body = format_rules["body"](node) or ""

    return ("%s %s %s\n%s\n%s"):format(method, target_url, http_version, headers, body)
  end,

  ["header"] = function(node)
    local name, value = get_fields(node)

    name = capitalize(name)
    return ("%s: %s"):format(name, value)
  end,

  ["body"] = function(node)
    local body = node:field("body")
    if not body or #body == 0 then return end

    body = body[1]
    return format_rules[body:type()](body)
  end,

  ["raw_body"] = function(node)
    return get_text(node)
  end,
  ["multipart_form_data"] = function(node)
    return get_text(node)
  end,
  ["xml_body"] = function(node)
    return get_text(node)
  end,
  ["json_body"] = function(node)
    local json = Json.parse(get_text(node), { verbose = true })
    if not json then return end

    local formatted = vim.json.encode(json)
    return Json.format(formatted, { sort = Config.options.json_sort_keys })
  end,
  ["graphql_body"] = function(node)
    return get_text(node)
  end,
  ["_external_body"] = function(node)
    return get_text(node)
  end,
}

local function format_node(node)
  local node_type = node:type()
  local rule = format_rules[node_type]

  if rule then
    return rule(node)
  elseif node:child_count() > 0 then
    local nodes = {}

    for i = 0, node:named_child_count() - 1 do
      local child = node:named_child(i)
      table.insert(nodes, format_node(child))
    end

    return table.concat(nodes, "\n")
  else
    return get_text(node)
  end
end

M.format = function(buffer)
  buf = buffer or vim.api.nvim_get_current_buf()

  local lang = "kulala_http"
  local tree = ts.get_parser(buf, lang):parse()[1]

  return format_node(tree:root())
end

return M
