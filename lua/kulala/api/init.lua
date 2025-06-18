local DB = require("kulala.db")
local Logger = require("kulala.logger")

local M = {}

M.events = {
  ["after_next_request"] = {},
  ["after_request"] = {},
}

M.on = function(name, callback)
  if not M.events[name] then return Logger.error("Invalid event name: " .. name) end
  table.insert(M.events[name], callback)
end

M.trigger = function(name)
  local responses = DB.global_find_unique("responses")
  local response = responses and responses[#responses] or {}
  local events = M.events[name]

  if not events then return Logger.error("Invalid event name: " .. name) end

  for _, callback in ipairs(events) do
    callback { headers = response.headers, body = response.body, response = response }
  end

  if name == "after_next_request" then M.events[name] = {} end
end

return M
