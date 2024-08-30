local Parser = require("kulala.parser")
local M = {}

M.get_contents = function()
  local req = Parser.parse()
  local contents = {}
  if req.http_version ~= nil then
    req.http_version = " " .. req.http_version
  else
    req.http_version = ""
  end
  table.insert(contents, req.method .. " " .. req.url .. req.http_version)
  for header_key, header_value in pairs(req.headers) do
    table.insert(contents, header_key .. ": " .. header_value)
  end
  if req.body ~= nil then
    table.insert(contents, "")
    local body_as_table = vim.split(req.body, "\r?\n")
    for _, line in ipairs(body_as_table) do
      table.insert(contents, line)
    end
  end
  return contents
end

return M
