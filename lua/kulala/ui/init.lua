local Config = require("kulala.config")
local Inlay = require("kulala.inlay")
local Parser = require("kulala.parser")
local Cmd = require("kulala.cmd")
local M = {}

local config = Config.get_config()

local function pretty_ms(ms)
  return string.format("%.2fms", ms)
end

M.open = function()
  Inlay:show_loading()
  local ast = Parser:parse()
  if config.debug then
    vim.print(vim.inspect(ast))
  end
  vim.schedule(function()
    local start = vim.loop.hrtime()
    Cmd.run(ast)
    local elapsed = vim.loop.hrtime() - start
    local elapsed_ms = pretty_ms(elapsed / 1e6)
    Inlay:show_done(elapsed_ms)
  end)
end

return M
