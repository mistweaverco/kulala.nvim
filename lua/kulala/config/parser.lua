local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")

local M = {}

local function get_parser_ver(parser_path)
  local ts = Fs.read_json(parser_path .. "/tree-sitter.json") or {}
  return ts.metadata and ts.metadata.version
end

local function get_parser_path()
  return Fs.get_plugin_path { "..", "tree-sitter" }
end

local function setup_treesitter_main()
  local Db = require("kulala.db")

  local ts_config = require("nvim-treesitter.config")
  local parser_path = get_parser_path()

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
  local parser_path = get_parser_path()

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

local function setup_nvim_treesitter()
  local parsers = vim.F.npcall(require, "nvim-treesitter.parsers")

  if not parsers then
    return Logger.warn(
      "Nvim-treesitter not found. The kulala_http parser is required for syntax highlighting and formatting."
    )
  end

  if parsers.get_parser_configs then
    setup_treesitter_master()
  else
    setup_treesitter_main()
  end
end

local function has_kulala_parser()
  local ok, inspected = pcall(function()
    return vim.treesitter and vim.treesitter.language and vim.treesitter.language.inspect("kulala_http")
  end)

  if ok and type(inspected) == "table" and next(inspected) ~= nil then return true end

  local exts = { "so", "dylib", "dll" }
  for _, ext in ipairs(exts) do
    if #vim.api.nvim_get_runtime_file("parser/kulala_http." .. ext, true) > 0 then return true end
  end

  return false
end

M.set_kulala_parser = function()
  if has_kulala_parser() then
    local parser_path = get_parser_path()
    vim.opt.rtp:append(parser_path)
    vim.treesitter.language.register("kulala_http", { "http", "rest" })
  else
    setup_nvim_treesitter()
  end
end

return M
