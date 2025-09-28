local DB = require("kulala.db")
local Json = require("kulala.utils.json")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

M.stdin_cmd = function(cmdstring, response)
  local cmd = {}
  if Shell.has_sh() then
    -- Use sh on Unix-like systems
    table.insert(cmd, "sh")
    table.insert(cmd, "-c")
  elseif Shell.has_zsh() then
    -- Use zsh on macOS
    table.insert(cmd, "zsh")
    table.insert(cmd, "-c")
  elseif Shell.has_powershell() then
    -- Use PowerShell on Windows
    table.insert(cmd, "powershell")
    table.insert(cmd, "-Command")
  else
    Logger.error("env_stdin_cmd --> Shell not found: powershell, sh, or zsh.")
    return ""
  end

  -- Append the command string to the command table
  table.insert(cmd, cmdstring)

  local result = Shell.run(cmd, {
    sync = true,
    stdin = (response and response.body or nil),
    err_msg = "Failed to run stdin_cmd",
    abort_on_stderr = true,
  })

  return result and result.stdout:gsub("[\r\n]$", "")
end

M.stdin_cmd_pre = M.stdin_cmd

M.env_stdin_cmd = function(cmd, response)
  -- Extract environment variable name (first token)
  local env_name, cmd_string = cmd:match("^(%S+)(.*)$")

  if not env_name then
    Logger.error("env_stdin_cmd --> Malformed metatag")
    return ""
  end

  -- save the result to the environment variable
  DB.update().env[env_name] = M.stdin_cmd(cmd_string, response)
end

M.env_stdin_cmd_pre = M.env_stdin_cmd

M.jq = function(filter, response)
  if vim.tbl_keys(response.json) == 0 then return end

  local result = Shell.run(
    { "jq", filter },
    { sync = true, stdin = response.body_raw, err_msg = "Failed to filter with jq", abort_on_stderr = true }
  )

  if not result or result.stdout == "" then return end

  response.body = result.stdout
  response.json = Json.parse(result.stdout, { verbose = false }) or response.json
  response.filter = filter
end

return M
