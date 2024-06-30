local FS = require("kulala.utils.fs")
local M = {}

M.pipe = function(cmdstring, contents)
  -- build the command
  local cmd = {}
  for token in string.gmatch(cmdstring, "[^%s]+") do
    table.insert(cmd, token)
  end
  local cmd_exists = FS.command_exists(cmd[1])
  if not cmd_exists then
    vim.notify("Pipe --> Command not found: " .. cmd[1] .. ". Returning plain contents..", vim.log.levels.ERROR)
    return contents
  end
  return vim.system(cmd, { stdin = contents, text = true }):wait().stdout
end

return M
