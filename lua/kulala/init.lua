local UI = require("kulala.ui")
local CONFIG = require("kulala.config")
local JUMPS = require("kulala.jumps")
local M = {}

M.setup = function(config)
  CONFIG.set_config(config)
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

return M
