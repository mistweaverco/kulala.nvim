local Fs = require("kulala.utils.fs")

local M = {}

local parser_name = "kulala_http"
local filetypes = { "http", "rest" }
local queries_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "queries")
local query_dir = vim.fs.joinpath(queries_dir, parser_name)
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
  vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
      if not vim.list_contains(filetypes, args.match) then return end
      vim.treesitter.start(args.buf)
    end,
  })
end

local function save_parser_ver()
  require("kulala.db").settings:write { parser_ver = get_parser_ver() }
end

local function setup_tree_sitter()
  Fs.ensure_dir_exists(queries_dir)
  Fs.copy_dir(vim.fs.joinpath(parser_path, "queries", parser_name), vim.fs.joinpath(queries_dir, parser_name))
end

local function has_kulala_parser()
  if not Fs.dir_exists(query_dir) then return false end
  return true
end

M.set_kulala_parser = function()
  local is_current = is_parser_ver_current()
  local needs_install = not is_current or not has_kulala_parser()
  if needs_install then return setup_tree_sitter() end
  if not is_current then save_parser_ver() end
  register_parser()
end

return M
