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

  Health.start("Response formatting:")
  Health.ok("Response bodies are formatted by kulala-core (see `response_format` in setup)")
end

return M
