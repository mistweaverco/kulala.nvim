local FS = require("kulala.utils.fs")
local DB = require("kulala.db")

local M = {}

M.env_stdin_cmd = function(cmdstring, contents)
  local cmd = {}
  local splitted = vim.split(cmdstring, " ")
  local env_name = splitted[1]
  local cmd_exists = FS.command_exists(splitted[2])
  if not cmd_exists then
    vim.notify("env_stdin_cmd --> Command not found: " .. cmd[2] .. ".", vim.log.levels.ERROR)
    return
  end
  table.remove(splitted, 1)
  for _, token in ipairs(splitted) do
    table.insert(cmd, token)
  end
  local res = vim.system(cmd, { stdin = contents, text = true }):wait().stdout
  if res == nil then
    vim.notify("env_stdin_cmd --> Command failed: " .. cmd[2] .. ".", vim.log.levels.ERROR)
    return
  else
    DB.data.env[env_name] = res
  end
end

M.stdin_cmd = function(cmdstring, contents)
  local cmd = {}
  for token in string.gmatch(cmdstring, "[^%s]+") do
    table.insert(cmd, token)
  end
  local cmd_exists = FS.command_exists(cmd[1])
  if not cmd_exists then
    vim.notify("stdin_cmd --> Command not found: " .. cmd[1] .. ". Returning plain contents..", vim.log.levels.ERROR)
    return contents
  end
  local res = vim.system(cmd, { stdin = contents, text = true }):wait().stdout
  return res
end

return M
