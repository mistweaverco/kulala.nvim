-- Kulala CLI Default Configuration
--
-- This file contains the default configuration for the Kulala CLI.
-- You can override these settings in several ways (in order of priority):
--
-- 1. Default CLI config (this file)
-- 2. User config: ~/.config/nvim/kulala/cli.lua
-- 3. Project-local config: .kulala-cli.lua in current working directory
-- 4. CLI-specified config: -c/--config <path>
-- 5. Inline overrides: --set key=value (supports nested keys like ui.default_view=body)
-- 6. Direct CLI flags: -e, -v, --halt, etc.
--
-- To create a custom config, copy this file and modify the values.
-- Example usage:
--   nvim --headless -l kulala_cli.lua -c ./my-config.lua api.http
--   nvim --headless -l kulala_cli.lua --set default_env=prod api.http
--   nvim --headless -l kulala_cli.lua --set ui.default_view=verbose halt_on_error=true api.http

local M = {
  default_env = "dev",

  request_timeout = nil,
  halt_on_error = false,

  lsp = { enable = false },

  ui = {
    default_view = "body",
    -- enable/disable request summary in the output window
    show_request_summary = true,
    -- disable notifications of script output
    disable_script_print_output = true,

    report = {
      -- possible values: true | false | "on_error"
      show_script_output = true,
      -- possible values: true | false | "on_error" | "failed_only"
      show_asserts_output = true,
      -- possible values: true | false | "on_error"
      show_summary = true,

      headersHighlight = "Special",
      successHighlight = "String",
      errorHighlight = "ErrorMsg",
    },
  },
}

return M
