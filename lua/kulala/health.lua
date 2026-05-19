local Config = require("kulala.config")
local Globals = require("kulala.globals")

local M = {}

local Health

M.check = function(health)
  Health = health or vim.health
  local config = Config.get()

  Health.start("System:")

  Health.info("{OS} " .. vim.uv.os_uname().sysname .. " " .. vim.uv.os_uname().release)
  Health.info("{Neovim} version " .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch)
  Health.info("{kulala.nvim} version " .. Globals.VERSION)

  Health.start("Tools:")

  local Bridge = require("kulala.cmd.kulala_core_bridge")
  local configured = config.kulala_core.path
  if Bridge.enabled() then
    local resolved = Bridge.executable_path()
    if type(configured) == "string" and vim.trim(configured) ~= "" then
      Health.ok(("{kulala-core} configured: %s → %s"):format(vim.trim(configured), resolved))
    else
      Health.ok(("{kulala-core} resolved from PATH: %s"):format(resolved))
    end
    Health.info("{kulala-core} data dir: " .. Bridge.effective_data_dir())
  elseif type(configured) == "string" and vim.trim(configured) ~= "" then
    Health.error(("{kulala-core} kulala_core.path is not executable: %s"):format(vim.trim(configured)))
  else
    Health.error(
      "{kulala-core} "
        .. "kulala-core not found. "
        .. "Either let kulala.nvim auto-download and install kulala-core or set `kulala_core.path` in setup."
    )
  end

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
