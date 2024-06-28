local Ui = require("kulala.ui")
local Config = require("kulala.config")
local Jumps = require("kulala.jumps")
local M = {}

M.setup = function(config)
  Config.set_config(config)
end

M.run = function()
  Ui:open()
end

M.jump_next = function()
  Jumps.jump_next()
end

M.jump_prev = function()
  Jumps.jump_prev()
end

return M
