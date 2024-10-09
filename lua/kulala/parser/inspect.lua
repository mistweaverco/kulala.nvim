local Parser = require("kulala.parser")
local M = {}

M.get_contents = function()
  local req = Parser.parse()
  local contents = {}
  if req == nil then
    return contents
  end
  if req.http_version ~= nil then
    req.http_version = " " .. req.http_version
  else
    req.http_version = ""
  end
  table.insert(contents, req.method .. " " .. req.url .. req.http_version)
  for header_key, header_value in pairs(req.headers) do
    table.insert(contents, header_key .. ": " .. header_value)
  end
  -- Use the body_display, because it's meant to be human-readable
  -- e.g. without binary data
  if req.body_display ~= nil then
    -- use an empty line to separate headers and body
    table.insert(contents, "")
    local body_as_table = vim.split(req.body_display, "\r?\n")
    for _, line in ipairs(body_as_table) do
      table.insert(contents, line)
    end
  end
  return contents
end

return M
