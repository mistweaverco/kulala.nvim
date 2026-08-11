local CONFIG = require("kulala.config")

local M = {}

local log_levels = vim.log.levels

local NOTIFY_LEVELS = {
  log = log_levels.INFO,
  info = log_levels.INFO,
  warn = log_levels.WARN,
  warning = log_levels.WARN,
  error = log_levels.ERROR,
  debug = log_levels.DEBUG,
}

local DEFAULT_TITLE = "kulala"

local is_headless = #vim.api.nvim_list_uis() == 0

---@param entry table
---@return string|nil
local function entry_message(entry)
  if type(entry) ~= "table" then return nil end
  local msg = entry.message
  if msg == nil then msg = entry["message"] end
  if msg == nil then return nil end
  msg = tostring(msg)
  if msg == "" then return nil end
  return msg
end

---@param entry table
---@return boolean
local function should_notify_entry(entry)
  local kind = entry.kind or entry["kind"]
  return kind ~= "test" and kind ~= "assert"
end

---@param config boolean|KulalaScriptConsoleNotifyConfig|nil
---@return boolean
local function is_enabled(config)
  if config == false then return false end
  if type(config) == "table" and config.enabled == false then return false end
  return config ~= nil
end

---@param entry table
---@return integer
local function notify_level(entry)
  local lvl = entry.level or entry["level"] or "log"
  return NOTIFY_LEVELS[lvl] or log_levels.INFO
end

---@param message string
---@param level integer
---@param opts table
local function default_notify(message, level, opts)
  if is_headless then return end

  local notify = vim.notify
  if vim.in_fast_event() then
    ---@cast notify fun(msg: string, level: integer, opts: table): integer
    notify = vim.schedule_wrap(notify)
  end

  notify(message, level, opts)
end

---@param config boolean|KulalaScriptConsoleNotifyConfig|nil
---@return KulalaScriptConsoleNotifyConfig
local function resolve_config(config)
  if config == true or config == nil then return { enabled = true } end
  if config == false then return { enabled = false } end
  return config
end

---@return boolean
function M.enabled()
  return is_enabled(CONFIG.get().script_console_notify)
end

---Forward `console.*` / `client.log` lines from kulala-core to vim.notify (or a custom handler).
---@param lines table[]|nil kulala-core `scriptConsole`
function M.emit(lines)
  if type(lines) ~= "table" or #lines == 0 then return end

  local config = resolve_config(CONFIG.get().script_console_notify)
  if not is_enabled(config) then return end

  local title = config.title or DEFAULT_TITLE
  local notify_fn = config.notify or default_notify

  for _, entry in ipairs(lines) do
    if should_notify_entry(entry) then
      local message = entry_message(entry)
      if message then notify_fn(message, notify_level(entry), { title = title }, entry) end
    end
  end
end

return M
