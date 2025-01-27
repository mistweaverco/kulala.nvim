local Logger = require("kulala.logger")
local Globals = require("kulala.globals")
local Fs = require("kulala.utils.fs")
local M = {}

M.events = {
  ["after_next_request"] = {},
  ["after_request"] = {},
}

M.on = function(name, callback)
  if M.events[name] == nil then
    Logger.error("Invalid event name: " .. name)
    return
  end
  table.insert(M.events[name], callback)
end

M.trigger = function(name)
  if M.events[name] == nil then
    Logger.error("Invalid event name: " .. name)
    return
  end
  if name == "after_next_request" then
    local headers = Fs.read_file(Globals.HEADERS_FILE)
    local body = Fs.read_file(Globals.BODY_FILE)
    for _, callback in ipairs(M.events[name]) do
      callback({
        headers = headers,
        body = body,
      })
    end
    -- reset the queue
    M.events[name] = {}
  end
  if name == "after_request" then
    local headers = Fs.read_file(Globals.HEADERS_FILE)
    local body = Fs.read_file(Globals.BODY_FILE)
    for _, callback in ipairs(M.events[name]) do
      callback({
        headers = headers,
        body = body,
      })
    end
  end
end

return M
