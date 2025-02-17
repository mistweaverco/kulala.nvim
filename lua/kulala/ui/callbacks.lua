local M = {}

M.callbacks = {}

M.add = function(name, callback)
  if M.callbacks[name] == nil then M.callbacks[name] = {} end
  table.insert(M.callbacks[name], callback)
end

M.get = function(name)
  return M.callbacks[name] or {}
end

return M
