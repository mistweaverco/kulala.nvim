local CONFIG = require("kulala.config")
local GLOBALS = require("kulala.globals")
local FS = require("kulala.utils.fs")

local health = vim.health
local start = health.start
local ok = health.ok
local info = health.info
local warn = health.warn
local error = health.error

local M = {}

M.check = function()
  info("{kulala.nvim} version " .. GLOBALS.VERSION)
  if FS.command_exists("curl") then
    ok("{curl} found")
  else
    error("{curl} not found")
  end

  start("Checking formatters")
  for type, config in pairs(CONFIG.get().contenttypes) do
    if not config.formatter then
      warn(string.format("{%s} formatter not found", type))
    else
      ok(string.format("{%s} formatter: %s", type, table.concat(config.formatter, " ")))
    end
  end
end

return M
