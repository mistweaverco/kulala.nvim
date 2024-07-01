local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")
local CFG = CONFIG.get_config()
local M = {}

M.format = function(ft, contents)
  local cmd = {}
  local cmd_exists = false
  if ft == "json" then
    cmd = CFG.formatters.json
    cmd_exists = FS.command_exists("jq")
  elseif ft == "xml" then
    cmd = CFG.formatters.xml
    cmd_exists = FS.command_exists("xmllint")
  elseif ft == "html" then
    cmd = CFG.formatters.html
    cmd_exists = FS.command_exists("xmllint")
  end
  if not cmd_exists then
    return contents
  end
  return vim.system(cmd, { stdin = contents, text = true }):wait().stdout
end

return M
