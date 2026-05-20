local DOCUMENT = require("kulala.parser.document")
local Fs = require("kulala.utils.fs")
local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")
local Logger = require("kulala.logger")
local Parserutils = require("kulala.parser.utils")
local Stringutils = require("kulala.utils.string")

local M = {}

M.download_schema = function()
  local requests = DOCUMENT.get_document()
  if not requests or #requests == 0 then return Logger.error("No request found") end
  local req = requests[1]

  if not Parserutils.contains_header(req.headers, "x-request-type", "GraphQL") then
    return Logger.warn("Not a GraphQL request")
  end

  local headers = vim.deepcopy(req.headers or {})
  if not Parserutils.contains_header(headers, "content-type", "application/json") then
    headers["Content-Type"] = "application/json"
  end

  local filename = req.url:gsub("https?://", ""):match("([^/]+)")
  filename = Fs.get_current_buffer_dir() .. "/" .. filename .. ".graphql-schema.json"

  local fp = Fs.get_plugin_path { "graphql", "introspection.graphql" }
  local gqlq = Stringutils.remove_extra_space(Stringutils.remove_newline(Fs.read_file(fp)))
  local body = vim.json.encode { query = gqlq }

  local _, core_cwd = KULALA_CORE.resolve_document_paths(0, req.file)

  local result, err = KULALA_CORE.http_request({
    url = req.url,
    method = "POST",
    headers = headers,
    body = body,
    timeoutSec = 120,
  }, core_cwd)

  if err then return Logger.error("Failed to download GraphQL schema: " .. err) end

  Fs.write_file(filename, result.body or "")
  Logger.info("Schema downloaded to " .. filename)
end

return M
