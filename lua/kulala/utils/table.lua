local M = {}

M.slice = function(tbl, first, last)
  local sliced = {}

  -- Adjust for out-of-bound indices
  first = first or 1
  last = last or #tbl
  if first < 1 then first = 1 end
  if last > #tbl then last = #tbl end

  -- Extract the slice
  for i = first, last do
    sliced[#sliced + 1] = tbl[i]
  end

  return sliced
end

M.remove_keys = function(tbl, keys)
  vim.iter(keys):each(function(key)
    tbl[key] = nil
  end)
  return tbl
end

M.filter = function(item, keys)
  keys = type(keys) == "table" and keys or { keys }
  if type(item) ~= "table" then return item end

  local ret = {}

  for k, v in pairs(item) do
    if not vim.tbl_contains(keys, k) then
      ret[k] = M.filter(v, keys)
      if type(ret[k]) == "table" and not next(ret[k]) then ret[k] = nil end
    end
  end

  return ret
end

--- TODO: make recursive for nested tables
--- Merge table 2 into table 1
--- @param mode "force" | "keep" -- force: overwrite existing keys, keep: only add new keys
M.merge = function(mode, tbl_1, tbl_2)
  vim.iter(tbl_2):each(function(k, v)
    if not tbl_1[k] or mode == "force" then tbl_1[k] = v end
  end)

  return tbl_1
end

M.set_at = function(tbl, keys, value)
  local _tbl = tbl

  keys = type(keys) == "table" and keys or { keys }
  for i = 1, #keys - 1 do
    local key = keys[i]
    tbl[key] = tbl[key] or {}
    tbl = tbl[key]
  end

  tbl[keys[#keys]] = value

  return _tbl
end

return M
