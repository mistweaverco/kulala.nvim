local Fs = require("kulala.utils.fs")
local Javascript = require("kulala.parser.scripts.javascript")
local Lua = require("kulala.parser.scripts.lua")

local M = {}

local function is_empty(scripts)
  return #scripts.inline == 0 and #scripts.files == 0
end

---@param type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request" -- type of script
---@param request Request
---@param response Response|nil
--- @return boolean status
M.run = function(type, request, response)
  local scripts = request.scripts[type]

  local lua = { inline = {}, files = {}, priority = scripts.priority }
  local js = { inline = {}, files = {}, priority = scripts.priority }

  local status = false

  if is_empty(scripts) then return false end

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

  local request_vars = Fs.read_json(Fs.get_request_scripts_variables_file_path()) or {}

  request_vars.__skip_request = nil
  request_vars.__replay_request = nil

  if not request_vars.__iteration then
    request_vars.__iteration = 1
    request_vars.__iteration_type = type
  elseif request_vars.__iteration_type == type then
    request_vars.__iteration = request_vars.__iteration + 1 -- increment only in the same type of request
  end

  Fs.write_json(Fs.get_request_scripts_variables_file_path(), request_vars)

  status = not is_empty(lua) and Lua.run(type, lua, request, response)
  status = not is_empty(js) and Javascript.run(type, js) or status

  return status
end

return M
