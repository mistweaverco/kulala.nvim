local Parser = require("kulala.config.parser")
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
  vim.fn.sign_define {
    { name = "kulala.done", text = M.options.icons.inlay.done, texthl = M.options.ui.icons.doneHighlight },
    { name = "kulala.error", text = M.options.icons.inlay.error, texthl = M.options.ui.icons.errorHighlight },
    { name = "kulala.loading", text = M.options.icons.inlay.loading, texthl = M.options.ui.icons.loadingHighlight },
    { name = "kulala.space", text = " " },
  }
end

local function set_legacy_options()
  M.options = vim.tbl_deep_extend("keep", M.options, M.options.ui)
end

local set_autocomands = function()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("Kulala filetype setup", { clear = true }),
    pattern = M.options.lsp.filetypes,
    callback = function(ev)
      _ = M.options.lsp.enable and require("kulala.cmd.lsp").start(ev.buf, ev.match)
    end,
  })
end

local function set_syntax_hl()
  vim.iter(M.options.ui.syntax_hl or {}):each(function(hl, group)
    group = type(group) == "string" and { link = group } or group
    vim.api.nvim_set_hl(0, hl, group)
  end)
end

M.setup = function(config)
  M.user_config = config or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, M.user_config)

  set_legacy_options()
  Parser.set_kulala_parser()
  set_syntax_hl()
  set_autocomands()

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
