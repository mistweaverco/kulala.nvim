local M = {}

local default_options = {
  title = "kulala",
}

local log_levels = vim.log.levels

M.log = function(message)
  vim.notify(message, log_levels.INFO, default_options)
end

M.info = function(message)
  vim.notify(message, log_levels.INFO, default_options)
end

M.warn = function(message)
  vim.notify(message, log_levels.WARN, default_options)
end

M.error = function(message)
  vim.notify(message, log_levels.ERROR, default_options)
end

return M
