local UI = require("kulala.ui")
local SELECTOR = require("kulala.ui.selector")
local ENV_PARSER = require("kulala.parser.env")
local GLOBAL_STORE = require("kulala.global_store")
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local JUMPS = require("kulala.jumps")
local M = {}

M.setup = function(config)
  CONFIG.setup(config)
  GLOBAL_STORE.set("selected_env", CONFIG.get().default_env)
  vim.g.kulala_selected_env = CONFIG.get().default_env
  ENV_PARSER.load_envs()
end

M.run = function()
  UI:open()
end

M.replay = function()
  UI:replay()
end

M.copy = function()
  UI:copy()
end

M.version = function()
  local neovim_version = vim.fn.execute("version")
  vim.notify(
    "Kulala version: " .. GLOBALS.VERSION .. "\n\n" .. "Neovim version: " .. neovim_version,
    "info",
    { title = "Kulala" }
  )
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
    SELECTOR.select_env()
  end
end

M.scratchpad = function()
  UI:scratchpad()
end

M.set_selected_env = function(env)
  if env == nil then
    local has_telescope, telescope = pcall(require, "telescope")
    if has_telescope then
      telescope.extensions.kulala.select_env()
    else
      SELECTOR.select_env()
    end
    return
  end
  GLOBAL_STORE.set("selected_env", env)
end

return M
