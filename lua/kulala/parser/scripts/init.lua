local Javascript = require("kulala.parser.scripts.javascript")
local Lua = require("kulala.parser.scripts.lua")

local M = {}

---@param type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request" -- type of script
---@param request Request
---@param response Response|nil
M.run = function(type, request, response)
  local lua = { inline = {}, files = {} }
  local js = { inline = {}, files = {} }

  local scripts = request.scripts[type]

  if scripts.inline[1] and scripts.inline[1]:match("^%s*-- lua") then
    lua.inline = table.concat(scripts.inline, "\n", 2)
  else
    js.inline = table.concat(scripts.inline, "\n")
  end

  vim.iter(scripts.files):each(function(file)
    if file:match("%.lua$") then
      table.insert(lua.files, file)
    else
      table.insert(js.files, file)
    end
  end)

  _ = #lua.inline + #lua.files > 0 and Lua.run(type, lua, request, response)
  _ = #js.inline + #js.files > 0 and Javascript.run(type, js)
end

return M
