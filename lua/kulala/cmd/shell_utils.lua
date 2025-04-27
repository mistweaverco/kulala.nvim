local M = {}
local Logger = require("kulala.logger")

local cache = {}

M.has_command = function(cmd)
  return vim.fn.executable(cmd) == 1
end

M.has_powershell = function()
  if cache.has_powershell ~= nil then return cache._has_powershell end
  cache.has_powershell = M.has_command("powershell")
  return cache.has_powershell
end

M.has_sh = function()
  if cache.has_sh ~= nil then return cache.has_sh end
  cache.has_sh = M.has_command("sh")
  return cache.has_sh
end

M.has_zsh = function()
  if cache.has_zsh ~= nil then return cache.has_zsh end
  cache.has_zsh = M.has_command("zsh")
  return cache.has_zsh
end

---@class ShellOpts: vim.SystemOpts
---@field sync boolean|nil -- call :wait() and return vim.SystemCompleted
---@field err_msg string|nil -- error message on failure
---@field on_error fun(system: vim.SystemCompleted)|nil -- callback on failure
---@field abort_on_stderr boolean|nil -- abort if stderr is not empty

---@param cmd string[]
---@param opts ShellOpts
---@param on_exit fun(system: vim.SystemCompleted)|nil
---@return vim.SystemObj|vim.SystemCompleted|nil
M.run = function(cmd, opts, on_exit)
  if vim.fn.executable(cmd[1]) == 0 then return Logger.error("Command not found: " .. cmd[1]) end

  opts.text = opts.text or true
  opts.err_msg = (opts.err_msg or "Error running command") .. ": " .. table.concat(cmd, " ") .. "\n"

  local status, result = pcall(function()
    return vim.system(cmd, opts, function(system)
      if system.code ~= 0 or (opts.abort_on_stderr and system.stderr ~= "") then
        Logger.error(opts.err_msg .. "Code: " .. system.code .. ", " .. system.stderr, 2)
        _ = opts.on_error and opts.on_error(system)
        return
      end

      _ = on_exit and on_exit(system)
    end)
  end)

  if not status then return Logger.error(opts.err_msg .. result, 2) end
  result = opts.sync and result:wait() or result

  return result
end

return M
