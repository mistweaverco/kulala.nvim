local UI = require("kulala.ui")
local ENV_PARSER = require("kulala.parser.env")
local GLOBAL_STORE = require("kulala.global_store")
local CONFIG = require("kulala.config")
local JUMPS = require("kulala.jumps")
local M = {}

M.setup = function(config)
  CONFIG.set_config(config)
  GLOBAL_STORE.set("selected_env", CONFIG.get_config().default_env)
  vim.g.kulala_selected_env = CONFIG.get_config().default_env
  ENV_PARSER.load_envs()
end

M.run = function()
  UI:open()
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

M.set_selected_env = function(env)
  if not pcall(require, "telescope") and env == nil then
    vim.notify("Telescope is not installed and env was not supplied..", vim.log.levels.ERROR)
    return
  elseif env == nil then
    require("telescope").extensions.kulala.select_env()
    return
  end
  GLOBAL_STORE.set("selected_env", env)
end

return M
