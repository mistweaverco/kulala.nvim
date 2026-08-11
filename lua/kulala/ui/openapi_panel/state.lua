local M = {}

function M.default_folds(tree)
  local folds = {}
  local function walk(nodes)
    for _, node in ipairs(nodes or {}) do
      if node.id ~= "root" and node.children and #node.children > 0 then folds[node.id] = true end
      if node.children then walk(node.children) end
    end
  end
  walk(tree)
  return folds
end

function M.seed_try_values(tree)
  local values = {}
  local function walk(nodes)
    for _, node in ipairs(nodes or {}) do
      if node.kind == "tryItOut" and node.operationKey and node.paramName then
        values[node.operationKey] = values[node.operationKey] or {}
        if values[node.operationKey][node.paramName] == nil then
          values[node.operationKey][node.paramName] = node.defaultValue or ""
        end
      end
      if node.children then walk(node.children) end
    end
  end
  walk(tree)
  return values
end

---@param old_folds table<string, boolean>|nil
---@param tree table[]
---@return table<string, boolean>
function M.merge_folds(old_folds, tree)
  local merged = M.default_folds(tree)
  for id, folded in pairs(old_folds or {}) do
    if merged[id] ~= nil then merged[id] = folded end
  end
  return merged
end

---@param old_values table<string, table<string, string>>|nil
---@param tree table[]
---@return table<string, table<string, string>>
function M.merge_try_values(old_values, tree)
  local merged = M.seed_try_values(tree)
  if type(old_values) ~= "table" then return merged end

  local valid = {}
  local function walk(nodes)
    for _, node in ipairs(nodes or {}) do
      if node.kind == "tryItOut" and node.operationKey and node.paramName then
        valid[node.operationKey .. "\0" .. node.paramName] = true
      end
      if node.children then walk(node.children) end
    end
  end
  walk(tree)

  for op_key, params in pairs(old_values) do
    if type(params) == "table" then
      for param_name, value in pairs(params) do
        if valid[op_key .. "\0" .. param_name] then
          merged[op_key] = merged[op_key] or {}
          merged[op_key][param_name] = value
        end
      end
    end
  end
  return merged
end

return M
