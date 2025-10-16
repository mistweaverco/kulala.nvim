local Config = require("kulala.config")
local Fs = require("kulala.utils.fs")
local Globals = require("kulala.globals")

local M = {}

local Health

local function check_executable(name, path)
  if Fs.command_exists(path) then
    path = Fs.command_path(path)

    local version = vim.system({ path, "--version" }, { text = true }):wait()
    version = #version.stdout > 0 and version.stdout or version.stderr
    version = version and version:match("%sv?([%d%.]+)%s*") or "unknown"

    Health.ok(("{%s} found: %s (version: %s)"):format(name, path, version))
  else
    Health.error(string.format("{%s} not found", name))
  end
end

M.check = function(health)
  Health = health or vim.health
  local config = Config.get()

  Health.start("System:")

  Health.info("{OS} " .. vim.uv.os_uname().sysname .. " " .. vim.uv.os_uname().release)
  Health.info("{Neovim} version " .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch)
  Health.info("{kulala.nvim} version " .. Globals.VERSION)

  Health.start("Tools:")

  check_executable("cURL", config.curl_path)
  check_executable("gRPCurl", config.grpcurl_path)
  check_executable("websocat", config.websocat_path)
  check_executable("openssl", config.openssl_path)
  check_executable("NPM", "npm")

  Health.start("Formatters:")

  for format_type, cfg in pairs(config.contenttypes) do
    local formatter = type(cfg) == "string" and config.contenttypes[cfg] or cfg
    formatter = formatter and formatter.formatter

    if not formatter then
      Health.warn(("{%s} formatter not found"):format(format_type))
    else
      formatter = type(formatter) == "function" and { debug.getinfo(formatter, "S").source } or formatter
      Health.ok(("{%s} formatter: %s"):format(format_type, table.concat(formatter, " ")))
    end
  end
end

return M
