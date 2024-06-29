local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local FORMATTER = require("kulala.formatter")
local FS = require("kulala.utils.fs")

local M = {}

local function exec_cmd(cmd)
  return vim.system(cmd, { text = true }):wait().stdout
end

-- runs the cmd and maybe formats the result
M.run = function(result)
  exec_cmd(result.cmd)
  if result.ft then
    local body = FS.read_file(GLOBALS.BODY_FILE)
    FS.write_file(GLOBALS.BODY_FILE, FORMATTER.format(result.ft, body))
  end
end

return M

