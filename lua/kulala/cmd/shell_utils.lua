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

M.run = function(cmd, opts, on_exit)
  if vim.fn.executable(cmd[1]) == 0 then return Logger.error("Command not found: " .. cmd[1]) end

  local status, result = pcall(function()
    vim.system(cmd, opts, function(system)
      if system.code ~= 0 then
        Logger.error("Error running command: " .. cmd .. "\nCode: " .. system.code .. ", " .. system.stderr, 2)
      end

      _ = on_exit and on_exit(system)
    end)
  end)

  if not status then return Logger.error("Error running command: " .. cmd .. "\n" .. result) end

  return result
end

return M
