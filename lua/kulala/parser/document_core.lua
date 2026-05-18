local Bridge = require("kulala.cmd.kulala_core_bridge")
local Document = require("kulala.parser.document")

local M = {}

---@param method string|nil
---@return boolean
local function method_supported_by_core(method)
  return type(method) == "string" and method ~= ""
end

---@param doc table KulalaDocument JSON
---@return string|nil err first unsupported protocol message
function M.unsupported_protocol_error(_doc)
  return nil
end

---kulala-core block positions are 1-based lines in content after top `import`/`run` directives are removed.
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

---JetBrains `# @name REQUEST_ID` for {{REQUEST_ID.response...}} references.
---@param block table
---@return string
local function block_display_name(block)
  for _, op in ipairs(block.operators or {}) do
    if op.name == "name" and op.args and vim.trim(tostring(op.args)) ~= "" then return vim.trim(tostring(op.args)) end
  end
  return block.name or ""
end

---@param doc table
---@param content string
---@param path string|nil
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
        local method = (req.method or "GET"):upper()
        local request = Document.new_empty_document_request()
        request.shared = shared
        request.name = block_display_name(block)
        request.method = method
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
        request._kulala_core = method_supported_by_core(method)
        request._kulala_unsupported_protocol = false
        request.cmd = { Bridge.executable_path() or "kulala-core" }

        table.insert(requests, request)
      end
    end
  end

  return requests
end

return M
