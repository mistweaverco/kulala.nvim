local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")

local M = {}

local parser_name = "kulala_http"
local filetypes = { "http", "rest" }
local parser_exts = { "so", "dylib", "dll" }
local install_error =
  "Failed to install kulala_http parser. Please check your nvim-treesitter setup or install by other means."

local parser_path = Fs.get_plugin_path { "..", "tree-sitter" }

local function get_parser_ver()
  local ts = Fs.read_json(parser_path .. "/tree-sitter.json") or {}
  return ts.metadata and ts.metadata.version
end

local function is_parser_ver_current()
  return require("kulala.db").settings.parser_ver == get_parser_ver()
end

local function register_parser()
  vim.treesitter.language.register(parser_name, filetypes)
end

local function append_parser_path_to_rtp()
  vim.opt.rtp:append(parser_path)
end

local function save_parser_ver()
  require("kulala.db").settings:write { parser_ver = get_parser_ver() }
end

local function handle_install_result(is_installed)
  if is_installed then
    save_parser_ver()
    register_parser()
  else
    Logger.error(install_error)
  end
end

local function setup_nvim_treesitter_main()
  local ts_config = require("nvim-treesitter.config")

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

  require("nvim-treesitter").install({ parser_name }):wait(10000)
  handle_install_result(vim.tbl_contains(ts_config.get_installed("parsers"), parser_name))
end

local function setup_nvim_treesitter_master()
  local parsers = require("nvim-treesitter.parsers")

  local parser_config = parsers.get_parser_configs()
  parser_config.kulala_http = {
    install_info = {
      url = parser_path,
      files = { "src/parser.c" },
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
    filetype = "http",
  }

  require("nvim-treesitter.install").commands.TSInstallSync["run!"](parser_name)
  handle_install_result(parsers.has_parser(parser_name))
end

local function setup_with_nvim_treesitter()
  local parsers = vim.F.npcall(require, "nvim-treesitter.parsers")

  if not parsers then
    return Logger.warn(
      "Nvim-treesitter not found. The kulala_http parser is required for syntax highlighting and formatting."
    )
  end

  if parsers.get_parser_configs then
    setup_nvim_treesitter_master()
  else
    setup_nvim_treesitter_main()
  end
end

local function get_nvim_treesitter_install_dirs()
  local dirs = {}

  -- main branch install location
  table.insert(dirs, vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser"))

  -- master branch install location (uses nvim-treesitter config or package path)
  local ts_configs = vim.F.npcall(require, "nvim-treesitter.configs")
  if ts_configs and ts_configs.get_parser_install_dir then
    local ts_dir = ts_configs.get_parser_install_dir()
    if ts_dir then table.insert(dirs, ts_dir) end
  end

  return dirs
end

local function is_installed_by_nvim_treesitter()
  for _, dir in ipairs(get_nvim_treesitter_install_dirs()) do
    for _, ext in ipairs(parser_exts) do
      local parser_file = vim.fs.joinpath(dir, parser_name .. "." .. ext)
      if vim.uv.fs_stat(parser_file) then return true end
    end
  end
  return false
end

local function has_kulala_parser()
  local ok, inspected = pcall(function()
    return vim.treesitter and vim.treesitter.language and vim.treesitter.language.inspect(parser_name)
  end)

  if ok and type(inspected) == "table" and next(inspected) ~= nil then return true end

  for _, ext in ipairs(parser_exts) do
    if #vim.api.nvim_get_runtime_file("parser/" .. parser_name .. "." .. ext, true) > 0 then return true end
  end

  return false
end

M.set_kulala_parser = function()
  append_parser_path_to_rtp()

  local is_current = is_parser_ver_current()
  local needs_install = (is_installed_by_nvim_treesitter() and not is_current) or not has_kulala_parser()
  if needs_install then return setup_with_nvim_treesitter() end

  if not is_current then save_parser_ver() end
  register_parser()
end

return M
