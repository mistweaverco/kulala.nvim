local Config = require("kulala.config")
local Parser = require("kulala.parser")
local Term = require("kulala.term")
local M = {}

local config = Config.get_config()

M.open = function()
  local ast = Parser:parse()
  if config.debug then
    vim.print(vim.inspect(ast))
  end
  Term.run(ast.cmd)
end

return M
