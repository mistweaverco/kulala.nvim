local ShellUtils = require("kulala.cmd.shell_utils")
local DB = require("kulala.db")
local Logger = require("kulala.logger")

local M = {}

M.stdin_cmd = function(cmdstring, contents)
  local cmd = {}
  if ShellUtils.has_sh() then
    -- Use sh on Unix-like systems
    table.insert(cmd, "sh")
    table.insert(cmd, "-c")
  elseif ShellUtils.has_zsh() then
    -- Use zsh on macOS
    table.insert(cmd, "zsh")
    table.insert(cmd, "-c")
  elseif ShellUtils.has_powershell() then
    -- Use PowerShell on Windows
    table.insert(cmd, "powershell")
    table.insert(cmd, "-Command")
  else
    Logger.error("env_stdin_cmd --> Shell not found: powershell, sh, or zsh.")
    return ""
  end

  -- Append the command string to the command table
  table.insert(cmd, cmdstring)

  -- Execute the command with the provided contents as stdin
  local res = vim.system(cmd, { stdin = contents, text = true }):wait().stdout

  if not res then
    Logger.error("stdin_cmd --> Command failed: " .. cmdstring .. ".")
    return ""
  else
    -- Remove trailing newline and return the result
    return res:gsub("[\r\n]$", "")
  end
end

M.env_stdin_cmd = function(cmdstring, contents)
  -- Extract environment variable name (first token)
  local env_name, cmd_string = cmdstring:match("^(%S+)(.*)$")
  if not env_name then
    Logger.error("env_stdin_cmd --> Malformed metatag")
    return ""
  end

  -- save the result to the environment variable
  DB.data.env[env_name] = M.stdin_cmd(cmd_string, contents)
end

return M
