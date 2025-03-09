local M = {}

local default_options = {
  title = "kulala",
}

local log_levels = vim.log.levels

local function debug_level()
  local debug = require("kulala.config").get().debug
  return debug == nil and 0 or (debug == false and 1 or (debug == true and 4 or debug))
end

M.log = function(message)
  vim.notify(message, log_levels.INFO, default_options)
  return false
end

M.info = function(message)
  _ = debug_level() > 2 and vim.notify(message, log_levels.INFO, default_options)
  return false
end

M.warn = function(message)
  _ = debug_level() > 1 and vim.notify(message, log_levels.WARN, default_options)
  return false
end

---@param message string
---@param lines_no number|nil -- no of error lines to show
M.error = function(message, lines_no)
  local debug = debug_level()
  if debug == 0 then return end

  local lines = vim.split(message, "\n")
  lines_no = debug > 3 and #lines or lines_no or 1
  message = table.concat(lines, "\n", 1, lines_no)

  vim.notify(message, log_levels.ERROR, default_options)
  return false
end

return M
