local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")

local health = vim.health
local start = health.start
local ok = health.ok
local info = health.info
local warn = health.warn
local error = health.error

local M = {}

M.check = function()
  info("{kulala.nvim} version " .. GLOBALS.VERSION)
  local curl = CONFIG.get().curl_path
  if FS.command_exists(curl) then
    local curl_path = FS.command_path(curl)
    local curl_version = vim.fn.system({ curl_path, "--version" })
    ok(string.format("{curl} found: %s (version: %s)", curl_path, curl_version:gsub("^curl ([^ ]+).*", "%1")))
  else
    error(string.format("{%s} not found", curl))
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
