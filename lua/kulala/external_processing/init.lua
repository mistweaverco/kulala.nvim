local DB = require("kulala.db")
local Json = require("kulala.utils.json")
local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")
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

---@param filter string
---@param response Response
---@param cwd string|nil
---@param opts? { silent?: boolean }
---@return boolean ok
M.jq = function(filter, response, cwd, opts)
  opts = opts or {}
  if type(filter) ~= "string" or vim.trim(filter) == "" then return false end
  local raw = response.body_raw
  if type(raw) ~= "string" or raw == "" then return false end

  local content_type = response._kulala_media_type or "application/json"
  local filtered, err = KULALA_CORE.apply_jq_filter({
    rawBody = raw,
    filter = filter,
    contentType = content_type,
  }, cwd)

  if not filtered then
    if not opts.silent then Logger.error(tostring(err and err ~= "" and err or "Failed to filter with jq")) end
    return false
  end
  if filtered.text == "" or vim.trim(filtered.text) == "null" then return false end

  response.body = filtered.text
  response.json = Json.parse(filtered.text, { verbose = false }) or response.json
  response.filter = filter
  if filtered.body_type then response._kulala_body_type = filtered.body_type end
  if filtered.media_type then response._kulala_media_type = filtered.media_type end
  return true
end

return M
