local Parser = require("kulala.parser")
local Term = require("kulala.term")
local M = {}

M.open = function()
  local ast = Parser:parse()
  Term.run(ast.curl)
end

return M
