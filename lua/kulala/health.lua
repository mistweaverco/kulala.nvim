local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")

local health = vim.health

local M = {}

local function check_executable(name, path)
  if FS.command_exists(path) then
    path = FS.command_path(path)

    local version = vim.system({ path, "--version" }, { text = true }):wait()
    version = #version.stdout > 0 and version.stdout or version.stderr
    version = version and version:match("%sv?([%d%.]+)%s*") or "unknown"

    health.ok(("{%s} found: %s (version: %s)"):format(name, path, version))
  else
    health.error(string.format("{%s} not found", name))
  end
end

M.check = function()
  local config = CONFIG.get()

  health.info("{kulala.nvim} version " .. GLOBALS.VERSION)

  check_executable("cURL", config.curl_path)
  check_executable("gRPCurl", config.grpcurl_path)

  health.start("Checking formatters")

  for format_type, cfg in pairs(config.contenttypes) do
    local formatter = cfg.formatter

    if not formatter then
      health.warn(("{%s} formatter not found"):format(format_type))
    else
      formatter = type(formatter) == "function" and { debug.getinfo(formatter, "S").source } or formatter
      health.ok(("{%s} formatter: %s"):format(format_type, table.concat(formatter, " ")))
    end
  end
end

return M
