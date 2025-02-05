local Config = require("kulala.config")
local DB = require("kulala.db")
local Parser = require("kulala.parser")
local Parserutils = require("kulala.parser.utils")
local Cmd = require("kulala.cmd")
local Logger = require("kulala.logger")
local Fs = require("kulala.utils.fs")
local Stringutils = require("kulala.utils.string")

local M = {}

M.download_schema = function()
  local req = Parser.parse()

  if not req then
    Logger.error("No request found")
    return
  end

  if
    Parserutils.contains_meta_tag(req, "graphql") == false
    and Parserutils.contains_header(req.headers, "x-request-type", "GraphQL") == false
  then
    Logger.warn("Not a GraphQL request")
    return
  end

  if not Parserutils.contains_header(req.headers, "content-type", "application/json") then
    req.headers["Content-Type"] = "application/json"
  end

  local filename = vim.fn.expand("%:t:r") .. ".graphql-schema.json"
  local cmd = {
    Config.get().curl_path,
    "-s",
    "-o",
    filename,
    "-X",
    "POST",
  }

  for header_name, header_value in pairs(req.headers) do
    if header_name and header_value then
      table.insert(cmd, "-H")
      table.insert(cmd, header_name .. ": " .. header_value)
    end
  end

  table.insert(cmd, "-d")

  local fp = Fs.get_plugin_path({ "graphql", "introspection.graphql" })
  local gqlq = Stringutils.remove_extra_space(Stringutils.remove_newline(Fs.read_file(fp)))

  table.insert(cmd, '{"query": "' .. gqlq .. '"}')
  table.insert(cmd, req.url)

  vim.system(cmd, { text = true }, function(status)
    if status.code == 0 then
      Logger.info("Schema downloaded to " .. vim.fn.fnamemodify(filename, ":p"))
    else
      Logger.error("Failed to download schema: " .. (status.stderr or ""))
    end
  end)
end

return M
