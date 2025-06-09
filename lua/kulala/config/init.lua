local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")
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

local function get_parser_ver(parser_path)
  local ts = Fs.read_json(parser_path .. "/tree-sitter.json") or {}
  return ts.metadata and ts.metadata.version
end

local function set_kulala_parser()
  local parsers = vim.F.npcall(require, "nvim-treesitter.parsers")
  if not parsers then return Logger.warn("nvim-treesitter not found") end

  local Db = require("kulala.db")

  local parser_config = parsers.get_parser_configs()
  local parser_path = Fs.get_plugin_path({ "..", "tree-sitter" })

  vim.opt.rtp:append(parser_path)

  parser_config.kulala_http = {
    install_info = {
      url = parser_path,
      files = { "src/parser.c" },
      branch = "main",
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
    filetype = "http",
  }

  if not parsers.has_parser("kulala_http") or Db.settings.parser_ver ~= get_parser_ver(parser_path) then
    require("nvim-treesitter.install").commands.TSInstallSync["run!"]("kulala_http")
    Db.settings:write({ parser_ver = get_parser_ver(parser_path) })
  end

  vim.treesitter.language.register("kulala_http", { "http", "rest" })
end

local function set_syntax_hl()
  vim.iter(M.options.ui.syntax_hl or {}):each(function(hl, group)
    group = type(group) == "string" and { link = group } or group
    vim.api.nvim_set_hl(0, hl, group)
  end)
end

M.setup = function(config)
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})

  set_legacy_options()
  set_kulala_parser()
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
