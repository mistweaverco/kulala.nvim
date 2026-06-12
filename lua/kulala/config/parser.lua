local Api = require("kulala.api")
local Fs = require("kulala.utils.fs")
local GitUtils = require("kulala.utils.git")
local Globals = require("kulala.globals")
local Notify = require("kulala.ui.notify")

local M = {}

local parser_name = "kulala_http"
local filetypes = { "http", "rest" }
local queries_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "queries")
local parsers_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser")
local target_parser_ext = vim.fn.has("win32") == 1 and "dll" or vim.fn.has("macunix") == 1 and "dylib" or "so"
local parser_target_path = vim.fs.joinpath(parsers_dir, parser_name .. "." .. target_parser_ext)
local query_target_dir = vim.fs.joinpath(queries_dir, parser_name)
local site_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site")

local parser_source_path = vim.fs.joinpath(vim.fn.stdpath("data"), "kulala.nvim", "tree-sitter-kulala-http")
local parser_registered = false

local function is_parser_ver_current()
  return require("kulala.db").settings.parser_rev == Globals.TREESITTER_VERSION
end

--- HACK:
--- Neovim does not rescan rtp for parser/queries added mid-session. Re-appending
--- the site dir refreshes discovery after a fresh install/build.
local function ensure_site_rtp()
  vim.opt.rtp:remove(site_dir)
  vim.opt.rtp:append(site_dir)
end

local function sync_queries()
  local src = vim.fs.joinpath(parser_source_path, "queries", parser_name)
  if not Fs.dir_exists(src) then return end
  Fs.ensure_dir_exists(queries_dir)
  Fs.copy_dir_contents(src, query_target_dir)
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
  require("kulala.db").settings:write { parser_rev = Globals.TREESITTER_VERSION }
end

-- Grammar lives in its own repo, fetched + built on demand: a git submodule here
-- breaks blobless/partial clones (e.g. lazy.nvim), dirtying the worktree on update.
local function fetch_grammar(on_done)
  Fs.ensure_dir_exists(parser_source_path)
  local function fetch_checkout()
    GitUtils.git(parser_source_path, { "fetch", "--depth", "1", "origin", Globals.TREESITTER_VERSION }, function(res)
      if res.code ~= 0 then return on_done(res) end
      GitUtils.git(parser_source_path, { "checkout", "--quiet", "FETCH_HEAD" }, on_done)
    end)
  end
  if Fs.dir_exists(vim.fs.joinpath(parser_source_path, ".git")) then
    fetch_checkout()
  else
    GitUtils.git(parser_source_path, { "init", "--quiet" }, function(res)
      if res.code ~= 0 then return on_done(res) end
      GitUtils.git(parser_source_path, { "remote", "add", "origin", Globals.TREESITTER_REPO_URL }, function()
        fetch_checkout()
      end)
    end)
  end
end

local function build_parser(finish_progress_handler)
  Fs.ensure_dir_exists(parsers_dir)
  sync_queries()
  local output_path = vim.fs.joinpath(parsers_dir, parser_name .. "." .. target_parser_ext)
  vim.system({ "tree-sitter", "build", "-o", output_path }, { cwd = parser_source_path }, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        finish_progress_handler("Failed to build tree-sitter parser: " .. (obj.stderr or ""), false)
      end)
    else
      vim.schedule(function()
        ensure_site_rtp()
        save_parser_ver()
        M.register_parser()
        if vim.bo.filetype == "http" then vim.cmd("edit!") end
        finish_progress_handler("Tree-sitter parser is ready!", true)
      end)
    end
  end)
end

local function setup_tree_sitter()
  local setup_progress, setup_finish = Notify.create_progress_handler(Globals.NAME)
  setup_progress { message = "Setting up tree-sitter ..." }
  vim.schedule(function()
    fetch_grammar(function(res)
      if res.code ~= 0 then
        vim.schedule(function()
          setup_finish("Failed to fetch tree-sitter grammar: " .. (res.stderr or ""), false)
        end)
        return
      end
      build_parser(setup_finish)
    end)
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
