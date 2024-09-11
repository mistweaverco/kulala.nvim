local Config = require("kulala.config")
local Parser = require("kulala.parser")
local Parserutils = require("kulala.parser.utils")
local Cmd = require("kulala.cmd")
local Logger = require("kulala.logger")
local Fs = require("kulala.utils.fs")
local Stringutils = require("kulala.utils.string")

local M = {}

M.download_schema = function()
  local req = Parser.parse()
  if
    Parserutils.contains_meta_tag(req, "graphql") == false
    and Parserutils.contains_header(req.headers, "x-request-type", "GraphQL") == false
  then
    Logger.warn("Not a GraphQL request")
    return
  end
  local filename = vim.fn.expand("%:t:r") .. ".graphql-schema.json"
  local c = {
    Config.get().curl_path,
    "-s",
    "-o",
    filename,
    "-X",
    "POST",
  }
  for header_name, header_value in pairs(req.headers) do
    if header_name and header_value then
      table.insert(c, "-H")
      table.insert(c, header_name .. ": " .. header_value)
    end
  end
  table.insert(c, "-d")
  local fp = Fs.get_plugin_path({ "graphql", "introspection.graphql" })
  local gqlq = Stringutils.remove_extra_space(Stringutils.remove_newline(Fs.read_file(fp)))
  table.insert(c, '{"query": "' .. gqlq .. '"}')
  table.insert(c, req.url)
  Cmd.run(c, function(success, datalist)
    if success then
      Logger.info("Schema downloaded to " .. filename)
    else
      if #datalist > 0 and #datalist[1] > 0 then
        Logger.error("Failed to download schema")
        print(vim.inspect(datalist))
      end
    end
  end)
end

return M
