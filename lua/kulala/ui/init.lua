local Parser = require("kulala.parser")
local Term = require("kulala.term")
local M = {}

M.open = function()
  local ast = Parser:parse()
  if ast.headers['content-type'] == "application/json" then
    Term.run("curl -s -X ".. ast.request.method .." \'".. ast.request.url .."\' | jq .")
    return
  end
  Term.run("curl -s -X ".. ast.request.method .." \'".. ast.request.url .."\'")
end

return M
