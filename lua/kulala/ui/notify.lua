local Logger = require("kulala.logger")

local M = {}
---Create a progress callback handler that uses juu.progress if available, otherwise falls back to Logger.notify
---@param title string Title for the progress display
---@return function progress_callback A function that accepts {progress: number|nil, message: string}
---@return function finish_callback A function to call when progress is complete (optional message)
M.create_progress_handler = function(title)
  local has_juu, juu_progress = pcall(require, "juu.progress")
  local handle = nil

  if has_juu and juu_progress and juu_progress.handle then
    -- Create juu progress handle (with error handling)
    local success, created_handle = pcall(juu_progress.handle.create, {
      title = title,
      message = "Starting...",
      client = { name = title },
      percentage = 0,
      cancellable = false,
    })
    if success and created_handle then handle = created_handle end
  end

  local progress_callback = function(progress_data)
    if handle then
      -- Use juu.progress
      local message = progress_data.message or "In progress..."
      local report_data = { message = message }
      -- Only include percentage if it's provided (not nil)
      if progress_data.progress ~= nil then report_data.percentage = progress_data.progress end
      handle:report(report_data)
    else
      -- Fallback to Logger.notify
      Logger.notify(progress_data.message or "In progress...", Logger.LoggerLogLevels.info)
    end
  end

  local finish_callback = function(message, success)
    if handle then
      if message then handle:report {
        message = message,
        percentage = 100,
      } end
      handle:finish()
    else
      if message then
        Logger.notify(message, success and Logger.LoggerLogLevels.info or Logger.LoggerLogLevels.error)
      end
    end
  end

  return progress_callback, finish_callback
end

return M
