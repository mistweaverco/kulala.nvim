local Ui = require("kulala.ui")
local Config = require("kulala.config")
local M = {}

M.setup = function(config)
  Config.set_config(config)
end

M.run = function()
  Ui:open()
end

return M
