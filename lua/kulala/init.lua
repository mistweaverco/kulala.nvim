local UI = require("kulala.ui")
local M = {}

KULALA_CONFIG = {
}

M.setup = function(config)
  config = config or {}
  KULALA_CONFIG = vim.tbl_deep_extend("force", KULALA_CONFIG, config)
end

M.get_config = function()
  return KULALA_CONFIG
end

M.run = function()
  UI:open()
end

return M
