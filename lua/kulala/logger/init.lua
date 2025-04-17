local M = {}

local default_options = {
  title = "kulala",
}

local log_levels = vim.log.levels

local function debug_level()
  local debug = require("kulala.config").get().debug
  return debug == nil and 0 or (debug == false and 3 or (debug == true and 4 or debug))
end

M.log = function(message, level)
  level = level or log_levels.INFO
  local notify = vim.in_fast_event() and vim.schedule_wrap(vim.notify) or vim.notify
  notify(message, level, default_options)
end

M.info = function(message)
  _ = debug_level() > 2 and M.log(message, log_levels.INFO)
end

M.warn = function(message)
  _ = debug_level() > 1 and M.log(message, log_levels.WARN)
end

---@param message string
---@param lines_no number|nil -- no of error lines to show
M.error = function(message, lines_no)
  local debug = debug_level()
  if debug == 0 then return end

  local lines = vim.split(message, "\n")
  lines_no = debug > 3 and #lines or lines_no or 1
  message = table.concat(lines, "\n", 1, lines_no)

  M.log(message, log_levels.ERROR)
end

return M
