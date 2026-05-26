local Bridge = require("kulala.cmd.kulala_core_bridge")
local Document = require("kulala.parser.document")

local M = {}

---@param _doc table KulalaDocument JSON
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

---@param script_filepath string|nil
---@param http_filepath string|nil
---@return boolean
local function is_external_script_path(script_filepath, http_filepath)
  if type(script_filepath) ~= "string" or script_filepath == "" then return false end
  if http_filepath and script_filepath == http_filepath then return false end
  return not script_filepath:match("%.http$")
end

---@param script_filepath string
---@param http_filepath string|nil
---@return string
local function resolve_script_filepath(script_filepath, http_filepath)
  if script_filepath:match("^%a:[/\\]") or script_filepath:sub(1, 1) == "/" then
    return vim.fs.normalize(script_filepath)
  end
  local base = (http_filepath and http_filepath ~= "") and vim.fn.fnamemodify(http_filepath, ":h") or vim.loop.cwd()
  return vim.fs.normalize(vim.fs.joinpath(base, script_filepath))
end

---Map kulala-core `block.scripts` to nvim `Scripts` (LSP, export, outline).
---@param kulala_scripts table|nil
---@param http_filepath string|nil
---@return Scripts
local function scripts_from_core(kulala_scripts, http_filepath)
  local out = {
    pre_request = { inline = {}, files = {}, priority = nil },
    post_request = { inline = {}, files = {}, priority = nil },
  }
  if type(kulala_scripts) ~= "table" then return out end

  local mapping = { preRequest = "pre_request", postRequest = "post_request" }
  for core_key, nvim_key in pairs(mapping) do
    for _, script in ipairs(kulala_scripts[core_key] or {}) do
      local content = script.content
      local script_path = script.filepath
      if is_external_script_path(script_path, http_filepath) then
        out[nvim_key].priority = out[nvim_key].priority or "files"
        table.insert(out[nvim_key].files, resolve_script_filepath(script_path, http_filepath))
      elseif type(content) == "string" and content ~= "" then
        out[nvim_key].priority = out[nvim_key].priority or "inline"
        table.insert(out[nvim_key].inline, content)
      end
    end
  end

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
---@param path string|nil
---@return DocumentRequest[]
function M.to_document_requests(doc, path)
  local off = directive_offset(doc)
  local shared = Document.new_empty_document_request()
  shared.url = nil

  if doc.fileHeaderVariables then
    for k, v in pairs(doc.fileHeaderVariables) do
      shared.variables[k] = v
    end
  end

  local requests = {}

  ---@type table<string, table[]>
  local run_children_by_parent = {}
  for _, block in ipairs(doc.blocks or {}) do
    local parent = block.runParentBlock
    if type(parent) == "string" and parent ~= "" then
      run_children_by_parent[parent] = run_children_by_parent[parent] or {}
      table.insert(run_children_by_parent[parent], block)
    end
  end

  local function block_to_request(block)
    local req = block.request
    if not req or not req.url or req.url == "" then return nil end
    local method = (req.method or "GET"):upper()
    local request = Document.new_empty_document_request()
    request.shared = shared
    vim.iter(shared.variables):each(function(k, v)
      request.variables[k] = v
    end)
    request.name = block_display_name(block)
    request.method = method
    request.url = req.url or ""
    local http_version = req.httpVersion or ""
    if http_version:match("^HTTP/") then http_version = http_version:gsub("^HTTP/", "") end
    request.http_version = http_version
    request.headers, request.headers_raw = headers_from_section(req.headerSection)
    request.body = body_to_string(req.body)
    request.body_display = request.body
    request.start_line = (block.position and block.position.start or 1) + off
    request.end_line = block_end_line(block) + off
    request.show_icon_line_number = request.start_line
    request.file = path or ""
    request.scripts = scripts_from_core(block.scripts, path)
    request.redirect_response_body_to_files = redirects_from_request(req)
    request.environment = {}
    request._kulala_core = true
    request._kulala_unsupported_protocol = false
    request._kulala_block_name = block.name
    request.cmd = { Bridge.executable_path() or "kulala-core" }
    return request
  end

  for _, block in ipairs(doc.blocks or {}) do
    if Document.is_shared_block_name(block.name) then
      if block.preambleVariables then
        for k, v in pairs(block.preambleVariables) do
          shared.variables[k] = v
        end
      end
      shared.name = block.name or "KULALA_SHARED"
      shared.scripts = scripts_from_core(block.scripts, path)
      shared.start_line = (block.position and block.position.start or 1) + off
      shared.end_line = block_end_line(block) + off
      shared.file = path or ""
    elseif not block.runParentBlock and not run_children_by_parent[block.name] then
      local request = block_to_request(block)
      if request then table.insert(requests, request) end
    end
  end

  for parent_name, child_blocks in pairs(run_children_by_parent) do
    local parent_block = nil
    for _, block in ipairs(doc.blocks or {}) do
      if block.name == parent_name then
        parent_block = block
        break
      end
    end
    if not parent_block then goto next_run_parent end

    ---@class DocumentRequest
    local shell = Document.new_empty_document_request()
    shell.shared = shared
    shell.name = parent_block.name or ""
    shell.url = nil
    shell.start_line = (parent_block.position and parent_block.position.start or 1) + off
    shell.end_line = block_end_line(parent_block) + off
    shell.show_icon_line_number = shell.start_line
    shell.file = path or ""
    shell._kulala_block_name = parent_block.name
    shell._kulala_core = true
    shell._kulala_run_expander = true
    shell.cmd = { Bridge.executable_path() or "kulala-core" }

    for _, child in ipairs(child_blocks) do
      local child_request = block_to_request(child)
      if child_request then
        child_request.start_line = shell.start_line
        child_request.end_line = shell.end_line
        child_request.show_icon_line_number = shell.show_icon_line_number
        table.insert(shell.nested_requests, child_request)
      end
    end

    if #shell.nested_requests > 0 then table.insert(requests, shell) end
    ::next_run_parent::
  end

  return requests
end

return M
