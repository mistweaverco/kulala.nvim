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
  vim.schedule(function()
    local choice = vim.fn.confirm("This looks like a bug. Would you like to generate a bug report?", "&Yes\n&No", 1)
    if choice == 1 then require("kulala.logger.bug_report").generate_bug_report(message) end
  end)
end

M.log = function(message, level, opts)
  opts = vim.tbl_extend("force", default_options, opts or {})
  level = level or log_levels.INFO

  local notify = vim.notify

  if vim.fn.has("gui_running") == 0 then
    return vim.print(message)
  elseif vim.in_fast_event() then
    notify = vim.schedule_wrap(vim.notify)
  end

  notify(message, level, opts)
end

M.info = function(message, opts)
  _ = debug_level() > 2 and M.log(message, log_levels.INFO, opts)
end

M.warn = function(message, opts)
  _ = debug_level() > 1 and M.log(message, log_levels.WARN, opts)
end

---@param message string
---@param lines_no number|nil -- no of error lines to show
---@param report boolean|nil -- whether to generate a bug report
M.error = function(message, lines_no, opts)
  opts = opts or {}

  local debug = debug_level()
  if debug == 0 then return end

  local lines = vim.split(message, "\n")
  lines_no = debug > 3 and #lines or lines_no or 1

  local short_message = table.concat(lines, "\n", 1, lines_no)
  M.log(short_message, log_levels.ERROR)

  if require("kulala.config").options.generate_bug_report or opts.report then generate_bug_report(message) end
end

M.debug = function(message, opts)
  local time = vim.uv.hrtime() % 1e10 / 1e6
  time = math.floor(time * 100) / 100

  if debug_level() < 4 then return end
  M.log("[" .. time .. "] " .. message, log_levels.DEBUG, opts)
end

M.trace = function(message, opts)
  local trace = debug.traceback()
  if not trace then return end

  ---@diagnostic disable-next-line: cast-local-type
  trace = vim.split(trace, "\n")
  table.remove(trace, 1)
  table.remove(trace, 1)

  local ret = {}
  for i, line in pairs(trace) do
    line = line:gsub("\t", "")
    if not line:find("pcall") then ret[string.char(i + 64)] = line end
  end

  M.debug(message .. "\nTRACE:" .. vim.inspect(ret), opts)
end

return M
