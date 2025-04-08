local Javascript = require("kulala.parser.scripts.javascript")
local Lua = require("kulala.parser.scripts.lua")

local M = {}

---@param type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request" -- type of script
---@param request Request
---@param response Response|nil
--- @return boolean status
M.run = function(type, request, response)
  local lua = { inline = {}, files = {} }
  local js = { inline = {}, files = {} }

  local status = false
  local scripts = request.scripts[type]

  if scripts.inline[1] and scripts.inline[1]:match("^%s*-- lua") then
    lua.inline = scripts.inline
  else
    js.inline = scripts.inline
  end

  vim.iter(scripts.files):each(function(file)
    if file:match("%.lua$") then
      table.insert(lua.files, file)
    else
      table.insert(js.files, file)
    end
  end)

  status = #lua.inline + #lua.files > 0 and Lua.run(type, lua, request, response)
  status = #js.inline + #js.files > 0 and Javascript.run(type, js) or status

  return status
end

return M
