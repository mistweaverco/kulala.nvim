---@diagnostic disable: need-check-nil
local Logger = require("kulala.logger")

local M = {}

---Resumes a coroutine and logs erorrs if any
---@param co thread
---@param ... any
---@return boolean|nil, ... any
M.co_resume = function(co, ...)
  if not co or coroutine.status(co) ~= "suspended" then return false end

  local result = { coroutine.resume(co, ...) }
  if not result[1] then
    local trace = debug.traceback(co, result[2])
    return Logger.error("Error in coroutine: " .. trace, 1, { report = true })
  end

  return unpack(result)
end

---Yields a coroutine and optionally resumes on timeout
---@param co thread
---@param timeout number|nil
---@param ... any
---@return boolean|nil, ... any
M.co_yield = function(co, timeout, ...)
  if not co or coroutine.status(co) ~= "running" then return false end

  local timer, resumed

  if timeout then
    timer = vim.uv.new_timer()
    timer:start(timeout, 0, function()
      timer:close()
      if not resumed then M.co_resume(co, "timeout") end
    end)
  end

  local result = { coroutine.yield(...) }
  resumed = true
  if timer then pcall(timer.close, timer) end

  return true, unpack(result)
end

---If in coroutine, wraps a function in vim.schedule and executes it, suspending the coroutine until completion
---@param co thread
---@param fn function
---@param ... any, ... any
M.co_wrap = function(co, fn, ...)
  if not (co and coroutine.status(co) == "running") then return fn(...) end

  local args = { ... }

  vim.schedule(function()
    M.co_resume(co, fn(unpack(args)))
  end)

  return unpack({ M.co_yield(co) }, 2)
end

---If in coroutine, suspends it for a given number of milliseconds
---@param co thread
---@param ms number
M.co_sleep = function(co, ms)
  if not co then return end

  local timer = vim.uv.new_timer()
  timer:start(ms, 0, function()
    M.co_resume(co)
    timer:close()
  end)

  M.co_yield(co)
end

return M
