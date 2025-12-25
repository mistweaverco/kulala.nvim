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

local function get_parser_ver(parser_path)
  local ts = Fs.read_json(parser_path .. "/tree-sitter.json") or {}
  return ts.metadata and ts.metadata.version
end

local function setup_treesitter_main()
  local Db = require("kulala.db")

  local ts_config = require("nvim-treesitter.config")
  local parser_path = Fs.get_plugin_path { "..", "tree-sitter" }

  local install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
  vim.opt.rtp:prepend(install_dir)

  local function register_parser_config()
    require("nvim-treesitter.parsers").kulala_http = {
      install_info = {
        path = parser_path,
        generate = false,
        generate_from_json = false,
        queries = "queries/kulala_http",
      },
    }
  end

  vim.api.nvim_create_autocmd("User", {
    pattern = "TSUpdate",
    callback = register_parser_config,
  })

  register_parser_config()
  vim.opt.rtp:append(parser_path) -- make kulala_http queries available

  if
    vim.tbl_contains(ts_config.get_installed("parsers"), "kulala_http")
    and Db.settings.parser_ver == get_parser_ver(parser_path)
  then
    return vim.treesitter.language.register("kulala_http", { "http", "rest" })
  end

  require("nvim-treesitter").install({ "kulala_http" }):wait(10000)

  if vim.tbl_contains(ts_config.get_installed("parsers"), "kulala_http") then
    Db.settings:write { parser_ver = get_parser_ver(parser_path) }
    vim.treesitter.language.register("kulala_http", { "http", "rest" })
  else
    Logger.error("Failed to install kulala_http parser. Please check your nvim-treesitter setup.")
  end
end

local function setup_treesitter_master()
  local Db = require("kulala.db")

  local parsers = require("nvim-treesitter.parsers")
  local parser_config = parsers.get_parser_configs()
  local parser_path = Fs.get_plugin_path { "..", "tree-sitter" }

  vim.opt.rtp:append(parser_path) --  make kulala_http queries available

  parser_config.kulala_http = {
    install_info = {
      url = parser_path,
      files = { "src/parser.c" },
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
    filetype = "http",
  }

  if parsers.has_parser("kulala_http") and Db.settings.parser_ver == get_parser_ver(parser_path) then
    return vim.treesitter.language.register("kulala_http", { "http", "rest" })
  end

  require("nvim-treesitter.install").commands.TSInstallSync["run!"]("kulala_http")

  if parsers.has_parser("kulala_http") then
    Db.settings:write { parser_ver = get_parser_ver(parser_path) }
    vim.treesitter.language.register("kulala_http", { "http", "rest" })
  else
    Logger.error("Failed to install kulala_http parser. Please check your nvim-treesitter setup.")
  end
end

local function set_kulala_parser()
  local parsers = vim.F.npcall(require, "nvim-treesitter.parsers")

  if not parsers then
    return Logger.warn("Nvim-treesitter not found. Required for syntax highlighting and formatting.")
  end

  if parsers.get_parser_configs then
    setup_treesitter_master()
  else
    setup_treesitter_main()
  end
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
