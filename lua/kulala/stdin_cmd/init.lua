local FS = require("kulala.utils.fs")
local M = {}

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
  vim.notify(vim.inspect(res), vim.log.levels.INFO)
  return res
end

return M
