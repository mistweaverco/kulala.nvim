local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local FORMATTER = require("kulala.formatter")
local CLIENT_PIPE = require("kulala.client_pipe")
local FS = require("kulala.utils.fs")

local M = {}

local function exec_cmd(cmd)
  return vim.system(cmd, { text = true }):wait().stdout
end

-- runs the cmd and maybe formats the result
M.run = function(result)
  exec_cmd(result.cmd)
  local body = FS.read_file(GLOBALS.BODY_FILE)

  if result.ft ~="text" and not result.client_pipe then
    body = FORMATTER.format(result.ft, body)
  end

  if result.client_pipe then
    body = CLIENT_PIPE.pipe(result.client_pipe, body)
  end

  FS.write_file(GLOBALS.BODY_FILE, FORMATTER.format(result.ft, body))
end

return M

