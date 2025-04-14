Snacks.notifier.reset_history()
local log = vim.schedule_wrap(LOG)

local co
co = coroutine.create(function()
  local i = 0
  local timer = vim.uv.new_timer()

  timer:start(1000, 1000, function()
    i = i + 1
    vim.schedule_wrap(LOG)(i)
    if i == 10 then
      log("resuming")
      coroutine.resume(co)
      timer:close()
    end
  end)

  coroutine.yield()

  log("Finished 0")
end)

coroutine.resume(co)
log("Finished 2")
