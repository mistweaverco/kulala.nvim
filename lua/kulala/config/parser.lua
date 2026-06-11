local Api = require("kulala.api")
local Fs = require("kulala.utils.fs")

local M = {}

local parser_name = "kulala_http"
local filetypes = { "http", "rest" }
local queries_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "queries")
local parsers_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser")
local target_parser_ext = vim.fn.has("win32") == 1 and "dll" or vim.fn.has("macunix") == 1 and "dylib" or "so"
local parser_target_path = vim.fs.joinpath(parsers_dir, parser_name .. "." .. target_parser_ext)
local query_target_dir = vim.fs.joinpath(queries_dir, parser_name)
local site_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
local parser_source_path = Fs.get_plugin_path { "..", "..", "tree-sitter-kulala-http" }
local parser_registered = false

local function get_parser_ver()
  local ts = Fs.read_json(parser_source_path .. "/tree-sitter.json") or {}
  return ts.metadata and ts.metadata.version
end

local function is_parser_ver_current()
  return require("kulala.db").settings.parser_ver == get_parser_ver()
end

--- HACK:
--- Neovim does not rescan rtp for parser/queries added mid-session. Re-appending
--- the site dir refreshes discovery after a fresh install/build.
local function ensure_site_rtp()
  vim.opt.rtp:remove(site_dir)
  vim.opt.rtp:append(site_dir)
end

local function sync_queries()
  Fs.ensure_dir_exists(queries_dir)
  Fs.copy_dir_contents(vim.fs.joinpath(parser_source_path, "queries", parser_name), query_target_dir)
end

local function load_parser()
  if not Fs.file_exists(parser_target_path) then return false end
  return vim.treesitter.language.add(parser_name) == true
end

M.register_parser = function()
  if parser_registered then return end
  if not load_parser() then return end
  parser_registered = true
  -- kulala_http/*.scm live under tree-sitter-kulala-http/queries/
  vim.opt.rtp:prepend(parser_source_path)
  ensure_site_rtp()
  sync_queries()
  vim.treesitter.language.register(parser_name, filetypes)
  vim.treesitter.language.register("markdown", "kulala_ui")
  local backend = require("kulala.backend")
  if not Api.has_triggered_ready() and backend.is_up_to_date() then Api.trigger("ready") end
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("KulalaTreesitter", { clear = true }),
    callback = function(args)
      if M.is_up_to_date() and vim.list_contains(filetypes, args.match) then
        if load_parser() then vim.treesitter.start(args.buf, parser_name) end
      end
    end,
  })
end

local function save_parser_ver()
  require("kulala.db").settings:write { parser_ver = get_parser_ver() }
end

local function setup_tree_sitter()
  Fs.ensure_dir_exists(parsers_dir)
  sync_queries()
  local output_path = vim.fs.joinpath(parsers_dir, parser_name .. "." .. target_parser_ext)
  vim.system({ "tree-sitter", "build", "-o", output_path }, {
    cwd = parser_source_path,
  }, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        print("Failed to build tree-sitter parser: " .. (obj.stderr or ""))
      end)
    else
      vim.schedule(function()
        ensure_site_rtp()
        save_parser_ver()
        M.register_parser()
        if vim.bo.filetype == "http" then vim.cmd("edit!") end
      end)
    end
  end)
end

local function has_kulala_parser()
  return Fs.file_exists(parser_target_path) and Fs.dir_exists(query_target_dir)
end

M.is_up_to_date = function()
  return has_kulala_parser() and is_parser_ver_current()
end

M.setup = function()
  if not M.is_up_to_date() then
    setup_tree_sitter()
    return
  end
  M.register_parser()
end

return M
