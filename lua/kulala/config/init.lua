local defaults = require("kulala.config.defaults")
local keymaps = require("kulala.config.keymaps")

local M = {}

M.defaults = defaults

M.default_contenttype = {
  ft = "text",
  formatter = nil,
  pathresolver = nil,
}

M.options = M.defaults

local function set_signcolumn_icons()
  vim.fn.sign_define({
    { name = "kulala.done", text = M.options.icons.inlay.done },
    { name = "kulala.error", text = M.options.icons.inlay.error },
    { name = "kulala.loading", text = M.options.icons.inlay.loading },
    { name = "kulala.space", text = " " },
  })
end

local function set_legacy_options()
  M.options = vim.tbl_deep_extend("keep", M.options, M.options.ui)
end

M.setup = function(config)
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})
  set_legacy_options()

  _ = M.options.show_icons == "signcolumn" and pcall(set_signcolumn_icons)
  M.options.global_keymaps, M.options.ft_keymaps = keymaps.setup_global_keymaps()

  M.options.initialized = true

  return M.options
end

M.set = function(config)
  M.options = vim.tbl_deep_extend("force", M.options, config or {})
end

M.get = function()
  return M.options
end

return M
