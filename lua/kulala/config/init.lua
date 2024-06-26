KULALA_CONFIG = KULALA_CONFIG or {
  debug = false,
}

local M = {}

M.set_config = function(config)
  config = config or {}
  KULALA_CONFIG = vim.tbl_deep_extend("force", KULALA_CONFIG, config)
end

M.get_config = function()
  return KULALA_CONFIG
end

return M
