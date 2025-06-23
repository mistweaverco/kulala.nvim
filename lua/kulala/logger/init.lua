local M = {}

local default_options = {
  title = "kulala",
}

local log_levels = vim.log.levels

local function debug_level()
  local debug = require("kulala.config").get().debug
  return debug == nil and 0 or (debug == false and 3 or (debug == true and 4 or debug))
end

local function generate_bug_report(message)
  local choice = vim.fn.confirm("This looks like a bug. Would you like to generate a bug report?", "&Yes\n&No", 1)
  if choice == 1 then require("kulala.logger.bug_report").generate_bug_report(message) end
end

M.log = function(message, level)
  level = level or log_levels.INFO
  local notify = vim.notify

  if not vim.fn.has("gui_running") then
    return vim.print(message)
  elseif vim.in_fast_event() then
    notify = vim.schedule_wrap(vim.notify)
  end

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
---@param report boolean|nil -- whether to generate a bug report
M.error = function(message, lines_no, report)
  local debug = debug_level()
  if debug == 0 then return end

  local lines = vim.split(message, "\n")
  lines_no = debug > 3 and #lines or lines_no or 1
  message = table.concat(lines, "\n", 1, lines_no)

  M.log(message, log_levels.ERROR)

  if require("kulala.config").options.generate_bug_report or report then generate_bug_report(message) end
end

return M
