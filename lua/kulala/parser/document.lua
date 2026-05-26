local DB = require("kulala.db")
local Diagnostics = require("kulala.cmd.diagnostics")
local FS = require("kulala.utils.fs")
local Logger = require("kulala.logger")
local PARSER_UTILS = require("kulala.parser.utils")

local M = {}

---@class DocumentRequest
---@field shared DocumentRequest
---@field metadata table<{name: string, value: string}>
---@field variables table<{name: string, value: string|number|boolean}>
---@field comments string[]
---
---@field method string
---@field url string
---@field request_target string|nil
---@field http_version string
---
---@field headers table<string, string>
---@field headers_raw table<string, string>
---@field cookie string
---
---@field body string
---@field body_display string
---@field inlined_files string[]
---
---@field start_line number
---@field end_line number
---@field show_icon_line_number number -- 1-based `###` delimiter line (icons / timings)
---
---@field redirect_response_body_to_files ResponseBodyToFile[]
---
---@field scripts Scripts
---
---@field name string|nil
---@field file string|nil -- The file the request was imported from, used for run()
---@field nested_requests DocumentRequest[] -- The nested requests, used for run()

---@alias DocumentVariables table<string, string|number|boolean>

---@class ResponseBodyToFile
---@field file string -- The file path to write the response body to
---@field overwrite boolean -- Whether to overwrite the file if it already exists

---@class Scripts
---@field pre_request ScriptData
---@field post_request ScriptData

---@class ScriptData
---@field inline string[]
---@field files string[]
---@field priority "inline"|"files"|nil -- execution order

---@type DocumentRequest
local default_document_request = {
  ---@diagnostic disable-next-line: missing-fields
  shared = {},
  metadata = {},
  variables = {},
  comments = {},
  method = "",
  url = "",
  request_target = "",
  http_version = "",
  headers = {},
  headers_raw = {},
  cookie = "",
  body = "",
  body_display = "",
  inlined_files = {},
  start_line = 1, -- 1-based
  end_line = 1, -- 1-based
  show_icon_line_number = 1,
  redirect_response_body_to_files = {},
  scripts = {
    pre_request = {
      inline = {},
      files = {},
      priority = nil,
    },
    post_request = {
      inline = {},
      files = {},
      priority = nil,
    },
  },
  name = nil,
  file = nil,
  nested_requests = {},
}

---Deep copy of an empty request (used by kulala-core adapter).
---@return DocumentRequest
function M.new_empty_document_request()
  return vim.deepcopy(default_document_request)
end

---@param name string|nil
---@return boolean
function M.is_shared_block_name(name)
  return name == "KULALA_SHARED" or name == "KULALA_SHARED_EACH"
end

---@param name string|nil
---@return boolean
function M.is_shared_each_block_name(name)
  return name == "KULALA_SHARED_EACH"
end

---kulala-core runs shared scripts via `sharedBlocks`; do not enqueue them as separate requests.
---@param requests DocumentRequest[]
---@return boolean
local function kulala_core_handles_shared_blocks(requests)
  for _, req in ipairs(requests) do
    if req._kulala_core == true then return true end
  end
  return false
end

local function is_runnable(request)
  local pre_scripts = request.scripts.pre_request
  local post_scripts = request.scripts.post_request

  return request.url
    or #pre_scripts.inline + #pre_scripts.files > 0
    or #post_scripts.inline + #post_scripts.files > 0
    or #request.nested_requests > 0
end

local function get_request_from_fenced_code_block()
  local buf = DB.get_current_buffer()
  local start_line = PARSER_UTILS.get_current_line_number()
  local total_lines = vim.api.nvim_buf_line_count(buf)
  if total_lines == 0 then return end

  local block_start
  for i = start_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
    if line:match("^%s*```") then
      block_start = i
      break
    end
  end
  if not block_start then return end

  local block_end
  for i = start_line, total_lines do
    local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
    if line:match("^%s*```") then
      block_end = i
      break
    end
  end
  if not block_end then return end

  return vim.api.nvim_buf_get_lines(buf, block_start, block_end - 1, false), block_start
end

local function get_visual_selection()
  if vim.api.nvim_get_mode().mode ~= "V" then return end

  vim.api.nvim_input("<Esc>")

  local line_s, line_e = vim.fn.getpos(".")[2], vim.fn.getpos("v")[2]
  if line_s > line_e then
    line_s, line_e = line_e, line_s
  end

  return vim.api.nvim_buf_get_lines(DB.get_current_buffer(), line_s - 1, line_e, false), line_s - 1
end

---kulala-core requires `###` block headers; wrap extracted snippets from non-.http buffers.
---@param lines string[]
---@return string[]
local function ensure_block_header(lines)
  if not lines or #lines == 0 then return lines end
  if lines[1]:match("^###") then return lines end
  return vim.list_extend({ "###" }, lines)
end

---@param lines string[]|nil
---@return string[]
local function resolve_content_lines(lines)
  if lines then return lines end

  local buf = DB.get_current_buffer()
  local content_lines, _ = get_visual_selection()

  if not content_lines and FS.is_non_http_file() then
    content_lines, _ = get_request_from_fenced_code_block()
    content_lines = content_lines or { vim.fn.getline(".") }
    content_lines = PARSER_UTILS.strip_invalid_chars(content_lines)
    content_lines = ensure_block_header(content_lines)
  end

  return content_lines or vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- expand path for included files, so can be used in request replay(), when cwd has changed
M.expand_included_filepath = function(path, lnum, file)
  path = path and FS.get_file_path(path, file)

  if FS.read_file(path, true) then
    return path
  else
    local msg = "The file '" .. path .. "' was not found."

    Logger.warn(msg)
    Diagnostics.add_diagnostics(DB.get_current_buffer(), msg, vim.diagnostic.WARN, lnum - 2, 0, lnum - 2, #path)

    return "[file not found] " .. path
  end
end

---Sets diagnostics for kulala-core parse errors,
---which are not associated with specific requests and should be cleared on each parse.
---@param bufnr number
---@param doc table|nil
---@return DocumentRequest[]|nil, DocumentRequest[]|nil
local function set_core_parse_diagnostics(bufnr, doc)
  Diagnostics.clear_diagnostics(bufnr, "parser")
  if not doc or not doc.hasErrors then return end
  local off = (type(doc.directiveLinesRemoved) == "number" and doc.directiveLinesRemoved) or 0
  for _, block in ipairs(doc.blocks or {}) do
    for _, err in ipairs(block.errors or {}) do
      local rel = err.lineNumber or 0
      local line = (block.position and block.position.start or 1) + rel + off
      Diagnostics.add_diagnostics(
        bufnr,
        err.errorMessage or "parse error",
        vim.diagnostic.severity.ERROR,
        math.max(0, line - 1),
        0,
        math.max(0, line - 1),
        1
      )
    end
  end
end

---Parses the buffer via kulala-core only (no legacy Lua parser).
---@param lines string[]|nil
---@param path string|nil
---@return DocumentRequest[]|nil, DocumentRequest[]|nil
M.get_document = function(lines, path)
  local Bridge = require("kulala.cmd.kulala_core_bridge")
  local DocCore = require("kulala.parser.document_core")

  local buf = DB.get_current_buffer()
  local content_lines = resolve_content_lines(lines)
  local content = table.concat(content_lines, "\n")
  local filepath_core, parse_cwd, filepath_display = Bridge.resolve_document_paths(buf, path)

  local doc, parse_err = Bridge.parse_document(content, filepath_core, parse_cwd)
  if parse_err then
    Logger.error("kulala-core parse failed: " .. parse_err, 1, { report = true })
    return nil, {}
  end

  if not doc or not doc.blocks or #doc.blocks == 0 then
    Logger.warn("No requests found in document")
    return nil, {}
  end

  if not path then set_core_parse_diagnostics(buf, doc) end

  local proto_err = DocCore.unsupported_protocol_error(doc)
  if proto_err then Logger.warn(proto_err) end

  local requests = DocCore.to_document_requests(doc, filepath_display)
  if #requests == 0 then
    Logger.warn("No runnable HTTP requests in document")
    return nil, {}
  end

  return requests, {}
end

local function apply_shared_data(shared, request)
  local request_metadata = vim
    .iter(request.metadata)
    :map(function(metadata)
      return metadata.name
    end)
    :totable()

  vim.iter(shared.metadata):each(function(metadata)
    if not vim.tbl_contains(request_metadata, metadata.name) then table.insert(request.metadata, metadata) end
  end)

  vim.iter(shared.variables):each(function(k, v)
    if not request.variables[k] then request.variables[k] = v end
  end)

  if not shared.url then -- only apply shared headers if request url is NOP
    vim.iter(shared.headers):each(function(k, v)
      if not request.headers[k] then request.headers[k] = v end
    end)
  end

  for _, key in ipairs { "pre_request", "post_request" } do
    local into = request.scripts[key]
    local from = shared.scripts[key]
    if from and (#from.inline > 0 or #from.files > 0) then
      into.inline = vim.list_extend(vim.deepcopy(from.inline), into.inline)
      into.files = vim.list_extend(vim.deepcopy(from.files), into.files)
      into.priority = into.priority or from.priority
    end
  end

  return request
end

local function expand_nested_requests(requests, lnum)
  requests = vim.islist(requests) and requests or { requests }

  local expanded = {}
  local shared = requests[1].shared

  if
    not M.is_shared_block_name(requests[1].name)
    and is_runnable(shared)
    and not kulala_core_handles_shared_blocks(requests)
  then
    if M.is_shared_each_block_name(shared.name) then
      local requests_ = vim.deepcopy(requests)
      requests = {}

      vim.iter(requests_):each(function(request)
        table.insert(requests, shared)
        table.insert(requests, request)
      end)
    else
      table.insert(requests, 1, shared)
    end
  end

  vim.iter(requests):each(function(request)
    request = apply_shared_data(shared, request)

    -- `run ./file.http` expander: one kulala-core run returns every nested response.
    if request._kulala_run_expander then
      table.insert(expanded, request)
      return
    end

    vim.iter(request.nested_requests):each(function(nested_request)
      nested_request.show_icon_line_number = lnum or nested_request.show_icon_line_number
      vim.list_extend(expanded, expand_nested_requests(nested_request, nested_request.show_icon_line_number))
    end)

    table.insert(expanded, request)
  end)

  return expanded
end

local function get_run_requests(request, line)
  local request_name = line:match("^run #(.+)$")
  request_name = request_name and request_name:gsub("%s*%(.+%)%s*$", "")

  local file = line:match("^run (.+%.http)%s*$")
  file = file and vim.fn.fnamemodify(file, ":t")

  if not (request_name or file) then return {} end

  return vim
    .iter(request.nested_requests)
    :filter(function(req)
      return (request_name and req.name == request_name) or (file and vim.fn.fnamemodify(req.file, ":t") == file)
    end)
    :totable()
end

---Returns DocumentRequests around specified line number from a list of DocumentRequests
---or the first DocumentRequest in the list if no line number is provided
---or all requests if linenr = 0
---or requests specified by `run` at specified line number
---@param requests DocumentRequest[]
---@param linenr? number|nil
---@return DocumentRequest[]|nil
M.get_request_at = function(requests, linenr)
  local status, result = xpcall(function()
    if not linenr then return expand_nested_requests(requests[1]) end
    if linenr == 0 then return expand_nested_requests(requests) end

    local request = requests[1]
    if not request then return {} end

    local shared = request.shared
    if
      not M.is_shared_block_name(request.name)
      and is_runnable(shared)
      and not kulala_core_handles_shared_blocks(requests)
    then
      table.insert(requests, 1, shared)
    end

    request = vim.iter(requests):find(function(req)
      return linenr >= req.start_line and linenr <= req.end_line
    end)

    if not request then return {} end

    local line = vim.fn.getline(linenr)
    if line:match("^run") then
      local nested = get_run_requests(request, line)

      -- kulala-core `run ./file.http`: nested targets use the parent buffer path, not the imported file name.
      if #nested == 0 and #request.nested_requests > 0 and line:match("^run .+%.http") then
        nested = request.nested_requests
      end

      -- Block has no URL; nested targets were expanded during parse_document().
      if #nested == 0 and #request.nested_requests == 0 then
        nested = vim
          .iter(requests)
          :filter(function(req)
            return req.start_line == request.start_line
          end)
          :totable()
      end

      return expand_nested_requests(nested)
    end

    return expand_nested_requests(request)
  end, debug.traceback)

  if not status then
    Logger.error(("Errors parsing the document: %s"):format(result), 1, { report = true })
    return {}
  end

  return result
end

M.get_previous_request = function(requests)
  DB.set_current_buffer()
  local cursor_line = PARSER_UTILS.get_current_line_number()

  for i, request in ipairs(requests) do
    if i > 1 and cursor_line >= request.start_line and cursor_line <= request.end_line then return requests[i - 1] end
  end
end

M.get_next_request = function(requests)
  DB.set_current_buffer()
  local cursor_line = PARSER_UTILS.get_current_line_number()

  for i, request in ipairs(requests) do
    if i < #requests and cursor_line >= request.start_line and cursor_line <= request.end_line then
      return requests[i + 1]
    end
  end
end

M.apply_shared_data = apply_shared_data

return M
