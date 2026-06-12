local M = {}

local default_options = {
  title = "kulala",
}

local log_levels = vim.log.levels

local is_headless = #vim.api.nvim_list_uis() == 0

local function debug_level()
  local debug = require("kulala.config").get().debug
  return debug == nil and 0 or (debug == false and 3 or (debug == true and 4 or debug))
end

M.LoggerLogLevels = {
  error = log_levels.ERROR,
  warn = log_levels.WARN,
  info = log_levels.INFO,
  debug = log_levels.DEBUG,
}

M.log = function(message, level, opts)
  if is_headless then return end
  opts = vim.tbl_extend("force", default_options, opts or {})
  level = level or log_levels.INFO

  local notify = vim.notify

  if vim.fn.has("gui_running") == 0 then
    return vim.print(message)
  elseif vim.in_fast_event() then
    local vim_notify = vim.notify
    ---@cast vim_notify fun(msg: string, level: integer, opts: table): integer
    notify = vim.schedule_wrap(vim_notify)
  end

  notify(message, level, opts)
end

M.notify = M.log

M.info = function(message, opts)
  if is_headless then return end
  if debug_level() > 2 then M.log(message, log_levels.INFO, opts) end
end

M.warn = function(message, opts)
  if is_headless then return end
  if debug_level() > 1 then M.log(message, log_levels.WARN, opts) end
end

---@param message string
---@param lines_no number|nil -- no of error lines to show
M.error = function(message, lines_no)
  if is_headless then return end

  local debug = debug_level()
  if debug == 0 then return end

  local lines = vim.split(tostring(message or ""), "\n")
  lines_no = debug > 3 and #lines or lines_no or 1
  lines_no = math.min(lines_no, math.max(#lines, 1))

  local short_message = table.concat(lines, "\n", 1, lines_no)
  M.log(short_message, log_levels.ERROR)
end

M.debug = function(message, opts)
  if is_headless then return end
  local time = vim.uv.hrtime() % 1e10 / 1e6
  time = math.floor(time * 100) / 100

  if debug_level() < 4 then return end
  M.log("[" .. time .. "] " .. message, log_levels.DEBUG, opts)
end

M.trace = function(message, opts)
  if is_headless then return end
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
