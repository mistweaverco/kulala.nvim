KULALA_GLOBAL_STORE = KULALA_GLOBAL_STORE or {}

local M = {}

M.set = function(key, value)
  KULALA_GLOBAL_STORE[key] = value
end

M.get = function(key)
  return KULALA_GLOBAL_STORE[key]
end

return M
