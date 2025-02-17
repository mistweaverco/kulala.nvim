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

---@param message string
---@param level number|nil -- debug level: no of error lines to show
M.error = function(message, level)
  local config = require("kulala.config").get()

  local lines = vim.split(message, "\n")
  level = config.debug and #lines or level or 1
  message = table.concat(lines, "\n", 1, level)

  vim.notify(message, log_levels.ERROR, default_options)
end

return M
