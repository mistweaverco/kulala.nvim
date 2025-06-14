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

local set_autocomands = function()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("Kulala filetype setup", { clear = true }),
    pattern = { "http", "rest", "json", "yaml", "bruno" },
    callback = function(ev)
      _ = M.options.lsp.enable and require("kulala.cmd.lsp").start(ev.buf, ev.match)
    end,
  })
end

M.setup = function(config)
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})

  set_legacy_options()
  set_autocomands()

  _ = M.options.ui.lua_syntax_hl and require("kulala.ui.treesitter").set()
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
