local Config = require("kulala.config")
local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")
local Parser = require("kulala.parser.request")
local Parserutils = require("kulala.parser.utils")
local Shell = require("kulala.cmd.shell_utils")
local Stringutils = require("kulala.utils.string")

local M = {}

M.download_schema = function()
  local req = Parser.parse()
  if not req then return Logger.error("No request found") end

  if not Parserutils.contains_header(req.headers, "x-request-type", "GraphQL") then
    return Logger.warn("Not a GraphQL request")
  end

  if not Parserutils.contains_header(req.headers, "content-type", "application/json") then
    req.headers["Content-Type"] = "application/json"
  end

  local filename = req.url:gsub("https?://", ""):match("([^/]+)")
  filename = Fs.get_current_buffer_dir() .. "/" .. filename .. ".graphql-schema.json"

  local cmd = { Config.get().curl_path, "-s", "-o", filename, "-X", "POST" }

  for header_name, header_value in pairs(req.headers) do
    if header_name and header_value then
      table.insert(cmd, "-H")
      table.insert(cmd, header_name .. ": " .. header_value)
    end
  end

  if req.cookie and #req.cookie > 0 then
    table.insert(cmd, "--cookie")
    table.insert(cmd, req.cookie)
  end

  table.insert(cmd, "-d")

  local fp = Fs.get_plugin_path { "graphql", "introspection.graphql" }
  local gqlq = Stringutils.remove_extra_space(Stringutils.remove_newline(Fs.read_file(fp)))

  table.insert(cmd, '{"query": "' .. gqlq .. '"}')
  table.insert(cmd, req.url)

  Shell.run(cmd, {
    err_msg = "Failed to download GraphQL schema",
    abort_on_stderr = true,
  }, function()
    Logger.info("Schema downloaded to " .. filename)
  end)
end

return M
