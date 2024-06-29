KULALA_CONFIG = KULALA_CONFIG or {
  -- default_view, body or headers
  default_view = "body",
  -- dev, test, prod, can be anything
  -- see: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
  default_env = "dev",
  -- enable/disable debug mode
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
