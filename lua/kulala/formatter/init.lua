local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")
local M = {}

M.format = function(ft, contents)
  local cfg = CONFIG.get()
  local cmd = {}
  local cmd_exists = false
  if ft == "json" then
    cmd = cfg.formatters.json
    cmd_exists = FS.command_exists("jq")
  elseif ft == "xml" then
    cmd = cfg.formatters.xml
    cmd_exists = FS.command_exists("xmllint")
  elseif ft == "html" then
    cmd = cfg.formatters.html
    cmd_exists = FS.command_exists("xmllint")
  end
  if not cmd_exists then
    return contents
  end
  return vim.system(cmd, { stdin = contents, text = true }):wait().stdout
end

return M
