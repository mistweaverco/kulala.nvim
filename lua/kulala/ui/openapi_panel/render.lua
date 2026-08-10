local M = {}

local DESC_MAX = 240

---@param text string
---@return string
local function truncate_desc(text)
  text = text:gsub("\r\n", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
  if #text <= DESC_MAX then return text end
  return text:sub(1, DESC_MAX - 1) .. "…"
end

---@param node table
---@param depth integer
---@param lines string[]
---@param line_map table[]
local function append_description(node, depth, lines, line_map)
  if type(node.description) ~= "string" or node.description == "" then return end
  local indent = string.rep("  ", depth + 1)
  local text = truncate_desc(node.description)
  for desc_line in text:gmatch("[^\n]+") do
    table.insert(lines, indent .. desc_line)
    table.insert(line_map, {
      kind = "text",
      id = node.id .. ":desc",
      parentId = node.id,
    })
  end
end

---@param nodes table[]
---@param folds table<string, boolean>
---@param try_values table<string, table<string, string>>
---@param depth integer
---@param lines string[]
---@param line_map table[]
---@param signs table { folded: string, expanded: string }
local function walk_tree(nodes, folds, try_values, depth, lines, line_map, signs)
  for _, node in ipairs(nodes or {}) do
    local folded = folds[node.id] == true
    local sign = folded and signs.folded or signs.expanded
    local indent = string.rep("  ", depth)
    local badge = node.badge and (" [" .. node.badge .. "]") or ""
    local line

    if node.kind == "tryItOut" and node.operationKey and node.paramName then
      local op_vals = try_values[node.operationKey] or {}
      local val = op_vals[node.paramName] or node.defaultValue or ""
      if node.paramName == "__body__" then
        line = indent .. sign .. " " .. node.title .. " = " .. val:gsub("\n", " ")
      else
        line = indent .. sign .. " " .. node.title .. " = " .. val
      end
    else
      line = indent .. sign .. " " .. node.title .. badge
    end

    table.insert(lines, line)
    table.insert(line_map, node)

    if not folded then
      append_description(node, depth, lines, line_map)
      if node.children and #node.children > 0 then
        walk_tree(node.children, folds, try_values, depth + 1, lines, line_map, signs)
      end
    end
  end
end

---@param tree table[]
---@param folds table<string, boolean>
---@param try_values table<string, table<string, string>>|nil
---@param signs table|nil
---@return string[] lines
---@return table[] line_map
function M.build_lines(tree, folds, try_values, signs)
  signs = signs or { folded = ">", expanded = "v" }
  try_values = try_values or {}
  local lines = {}
  local line_map = {}
  walk_tree(tree, folds, try_values, 0, lines, line_map, signs)
  return lines, line_map
end

return M
