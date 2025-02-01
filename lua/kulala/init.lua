local UI = require("kulala.ui")
local SELECTOR = require("kulala.ui.selector")
local ENV = require("kulala.parser.env")
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local JUMPS = require("kulala.jumps")
local Graphql = require("kulala.graphql")
local Logger = require("kulala.logger")
local ScriptsUtils = require("kulala.parser.scripts.utils")
local Fs = require("kulala.utils.fs")
local M = {}

M.setup = function(config)
  CONFIG.setup(config)
end

M.open = function()
  UI:open_default_view()
end

M.run = function()
  UI:open()
end

M.run_all = function()
  UI:open_all()
end

M.replay = function()
  UI:replay()
end

M.inspect = function()
  UI:inspect()
end

M.copy = function()
  UI:copy()
end

M.show_stats = function()
  UI:show_stats()
end

M.from_curl = function()
  UI:from_curl()
end

M.version = function()
  local neovim_version = vim.fn.execute("version") or "Unknown"
  Logger.info("Kulala version: " .. GLOBALS.VERSION .. "\n\n" .. "Neovim version: " .. neovim_version)
end

M.jump_next = function()
  JUMPS.jump_next()
end

M.jump_prev = function()
  JUMPS.jump_prev()
end

M.toggle_view = function()
  UI:toggle_headers()
end

M.close = function()
  UI:close()
end

M.search = function()
  local has_telescope, telescope = pcall(require, "telescope")
  if has_telescope then
    telescope.extensions.kulala.search()
  else
    SELECTOR.search()
  end
end

M.scripts_clear_global = function(key_or_keys)
  ScriptsUtils.clear_global(key_or_keys)
end

M.download_graphql_schema = function()
  Graphql.download_schema()
end

M.scratchpad = function()
  UI:scratchpad()
end

M.get_selected_env = function()
  return vim.g.kulala_selected_env or CONFIG.get().default_env
end

M.set_selected_env = function(env)
  ENV.get_env()
  if env == nil then
    local has_telescope, telescope = pcall(require, "telescope")
    if has_telescope then
      telescope.extensions.kulala.select_env()
    else
      SELECTOR.select_env()
    end
    return
  end
  vim.g.kulala_selected_env = env
end

---Clears all cached files
---Useful when you want to clear all cached files
M.clear_cached_files = function()
  Fs.clear_cached_files()
end

return M
