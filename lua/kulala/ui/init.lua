local Config = require("kulala.config")
local Parser = require("kulala.parser")
local Cmd = require("kulala.cmd")
local M = {}

local config = Config.get_config()

M.open = function()
  local ast = Parser:parse()
  if config.debug then
    vim.print(vim.inspect(ast))
  end
  Cmd.run(ast)
end

return M
