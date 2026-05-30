local M = {}

function M.install()
  local assert_mod = require("kulala.test_helper.assert")
  -- Keep busted-style `assert.are.*` while preserving Lua's `assert(cond, msg)`.
  _G.assert = setmetatable(assert_mod, {
    __call = function(_, cond, msg, level)
      if not cond then error(msg or "assertion failed!", level or 1) end
    end,
  })
  _G.stub = require("kulala.test_helper.mock").stub
  _G.pending = function(name, _f)
    _G.it(name .. " (pending)", function()
      require("mini.test").skip("pending")
    end)
  end
end

function M.uninstall()
  _G.assert = nil
  _G.stub = nil
  _G.pending = nil
end

return M
