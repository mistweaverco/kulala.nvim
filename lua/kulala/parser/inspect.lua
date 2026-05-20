local Logger = require("kulala.logger")
local Parser = require("kulala.parser.request")

local M = {}

M.get_contents = function()
  local contents = {}

  local request = Parser.parse()
  if not request then
    Logger.error("No requests found in the document")
    return contents
  end

  local version_suffix = ""
  if request.http_version and request.http_version ~= "" then
    if request.http_version:match("^HTTP/") then
      version_suffix = " " .. request.http_version
    else
      version_suffix = " HTTP/" .. request.http_version
    end
  end
  table.insert(contents, request.method .. " " .. request.url .. version_suffix)

  for header_key, header_value in pairs(request.headers_display) do
    table.insert(contents, header_key .. ": " .. header_value)
  end
  -- Use the body_display, because it's meant to be human-readable
  -- e.g. without binary data
  if request.body_display ~= nil then
    -- use an empty line to separate headers and body
    table.insert(contents, "")

    local body_as_table = vim.split(request.body_display, "\r?\n")
    for _, line in ipairs(body_as_table) do
      table.insert(contents, line)
    end
  end

  return contents
end

return M
