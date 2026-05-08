local Bridge = require("kulala.cmd.kulala_core_bridge")
local Document = require("kulala.parser.document")

local M = {}

---Protocols handled by the embedded kulala.nvim runner (gRPC / WebSocket), not HTTP-node runner.
local function block_needs_legacy_runner(block)
  local m = block.request and block.request.method
  return m == "GRPC" or m == "WS" or m == "WSS"
end

---@param doc table KulalaDocument JSON
---@return boolean
function M.needs_legacy_parser(doc)
  if not doc or type(doc.blocks) ~= "table" then return true end
  for _, block in ipairs(doc.blocks) do
    if block_needs_legacy_runner(block) then return true end
  end
  return false
end

---kulala-core block positions are 1-based lines in content after top `import`/`run` directives are removed;
---Neovim uses the full buffer, so add this offset.
---@param doc table
---@return number
local function directive_offset(doc)
  local n = doc and doc.directiveLinesRemoved
  if type(n) == "number" and n > 0 then return n end
  return 0
end

local function block_end_line(block)
  local pos = block.position
  if not pos then return 1 end
  local last = pos["end"]
  if type(last) ~= "number" then last = pos.start end
  return last
end

local function headers_from_section(header_section)
  local headers, headers_raw = {}, {}
  for _, entry in ipairs(header_section or {}) do
    if entry.type == "header" and entry.name then
      headers[entry.name] = entry.value or ""
      headers_raw[entry.name] = entry.value or ""
    end
  end
  return headers, headers_raw
end

local function body_to_string(body)
  local t = type(body)
  if t == "string" then return body end
  if t == "table" then return vim.json.encode(body) end
  return ""
end

local function redirects_from_request(req)
  local out = {}
  local rr = req.responseRedirect
  if rr and rr.filePath then table.insert(out, { file = rr.filePath, overwrite = rr.overwrite == true }) end
  return out
end

---Convert a Kulala core document to kulala.nvim DocumentRequest list.
---@param doc table
---@param content string full buffer text
---@param path string|nil absolute path to .http file
---@return DocumentRequest[]
function M.to_document_requests(doc, _content, path)
  local off = directive_offset(doc)
  local shared = Document.new_empty_document_request()
  shared.url = nil

  if doc.fileHeaderVariables then
    for k, v in pairs(doc.fileHeaderVariables) do
      shared.variables[k] = v
    end
  end

  local requests = {}

  for _, block in ipairs(doc.blocks or {}) do
    if block.name == "Shared" or block.name == "Shared each" then
      if block.preambleVariables then
        for k, v in pairs(block.preambleVariables) do
          shared.variables[k] = v
        end
      end
    else
      local req = block.request
      if req and req.url and req.url ~= "" then
        local request = Document.new_empty_document_request()
        request.shared = shared
        request.name = block.name
        request.method = req.method or "GET"
        request.url = req.url or ""
        request.http_version = req.httpVersion or ""
        request.headers, request.headers_raw = headers_from_section(req.headerSection)
        request.body = body_to_string(req.body)
        request.body_display = request.body
        request.start_line = (block.position and block.position.start or 1) + off
        request.end_line = block_end_line(block) + off
        request.show_icon_line_number = request.start_line
        request.file = path or ""
        request.redirect_response_body_to_files = redirects_from_request(req)
        request.environment = {}
        request._kulala_core = true
        request.cmd = { Bridge.executable_path() or "kulala-core" }

        table.insert(requests, request)
      end
    end
  end

  return requests
end

return M
