local Config = require("kulala.config")
local DB = require("kulala.db")
local Diagnostics = require("kulala.cmd.diagnostics")
local FS = require("kulala.utils.fs")
local Json = require("kulala.utils.json")
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
---@field show_icon_line_number number
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

local parse_document

local function is_runnable(request)
  local pre_scripts = request.scripts.pre_request
  local post_scripts = request.scripts.post_request

  return request.url
    or #pre_scripts.inline + #pre_scripts.files > 0
    or #post_scripts.inline + #post_scripts.files > 0
    or #request.nested_requests > 0
end

local function split_content_by_blocks(lines, line_offset)
  local new_block = { lines = {}, name = nil, start_lnum = math.max(1, line_offset), end_lnum = 1 }
  local delimiter = "###"
  local blocks = {}

  local block = vim.deepcopy(new_block)

  for lnum, line in ipairs(lines) do
    local is_delimiter = line:match("^" .. delimiter)

    if is_delimiter or lnum == #lines then
      if lnum == #lines and not is_delimiter then
        table.insert(block.lines, line)
        lnum = lnum + 1
      end

      block.end_lnum = math.max(1, line_offset + lnum - 1)
      _ = #block.lines > 0 and table.insert(blocks, block)

      block = vim.deepcopy(new_block)
      block.start_lnum = line_offset + lnum + 1
      block.name = line:match("^" .. delimiter .. "+ (.+)$")
    else
      table.insert(block.lines, line)
    end
  end

  return blocks
end

local function get_request_from_fenced_code_block()
  local buf = DB.get_current_buffer()
  local start_line = PARSER_UTILS.get_current_line_number()

  -- Get the total number of lines in the current buffer
  local total_lines = vim.api.nvim_buf_line_count(buf)
  if total_lines == 0 then return end

  -- Search for the start of the fenced code block (``` or similar)
  local block_start = nil
  for i = start_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
    if line:match("^%s*```") then
      block_start = i
      break
    end
  end

  -- If we didn't find a block start, return nil
  if not block_start then return end

  -- Search for the end of the fenced code block
  local block_end = nil
  for i = start_line, total_lines do
    local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
    if line:match("^%s*```") then
      block_end = i
      break
    end
  end

  -- If we didn't find a block end, return nil
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

  local contents = vim.api.nvim_buf_get_lines(DB.get_current_buffer(), line_s - 1, line_e, false)

  return contents, line_s - 1
end

local function parse_redirect_response(request, line)
  local overwrite, write_to_file = line:match("^>>(!?) (.*)$")

  table.insert(request.redirect_response_body_to_files, {
    file = write_to_file,
    overwrite = overwrite == "!",
  })
end

-- Variables are defined as `@variable_name=value`
-- The value can be a string, a number or boolean
local function parse_variables(request, line)
  local variable_name, variable_value = line:match("^@([%w_-]+)%s*=%s*(.*)$")
  if variable_name and variable_value then
    variable_name = variable_name:sub(1) -- remove the @ symbol from the variable name
    request.variables[variable_name] = variable_value

    if Config.options.variables_scope == "document" then request.shared.variables[variable_name] = variable_value end
  end
end

-- Metadata (e.g., # @this-is-name this is the value)
-- See: https://httpyac.github.io/guide/metaData.html
local function parse_metadata(request, line)
  if line:sub(1, 3) == "# @" then
    local meta_name, meta_value = line:match("^# @([%w+%-]+)%s*(.*)$")
    if meta_name and meta_value then table.insert(request.metadata, { name = meta_name, value = meta_value }) end
    if meta_name == "name" then request.name = meta_value end
  end
end

-- Header
-- Headers are defined as `key: value`
-- The key can be anything except a colon
-- The value can be a string or a number
-- The value can be a variable
-- The value can be a dynamic variable
-- variables are defined as `{{variable_name}}`
-- dynamic variables are defined as `{{$variable_name}}`
local function parse_headers(request, line)
  local key, value = line:match("^([^:]+):%s*(.*)$")

  if key == "Cookie" then
    request.cookie = #request.cookie == 0 and value or request.cookie .. "; " .. value
    return
  end

  if key and value then
    request.headers[key] = value
    request.headers_raw[key] = value
  end
end

local function parse_query_params(request, line)
  -- Query parameters for URL as separate lines
  local querypart, http_version = line:match("^%s*(.+)%s+HTTP/(%d[.%d]*)%s*$")
  querypart = querypart or line:match("^%s*(.+)%s*$")

  request.url = querypart and (request.url .. querypart) or request.url
  request.http_version = http_version or request.http_version
end

local function parse_body(request, line, lnum)
  request.body = request.body or ""
  request.body_display = request.body_display or ""

  local line_ending = "\n"
  local _, content_type = PARSER_UTILS.get_header(request.headers, "content-type")
  content_type = content_type or ""

  if line:find("^< [^{]") then
    local path = line:match("^< ([^\r\n]+)[\r\n]*$")
    line = "< " .. M.expand_included_filepath(path, lnum, request.file)
    table.insert(request.inlined_files, path)
  elseif content_type:find("^application/x%-www%-form%-urlencoded") then
    -- should be no line endings or they should be urlencoded
    line_ending = ""
  elseif content_type:find("^multipart/form%-data") then
    -- per RFC2616 3.7.2. and RFC2046 5.1.1 multipart boundaries endings and line endings must be represented as CRLF
    line_ending = "\r\n"
  end

  request.body = request.body .. line .. line_ending
  request.body_display = request.body_display .. line .. line_ending
end

local function infer_headers_from_body(request)
  if PARSER_UTILS.get_header(request.headers, "content-type") then return end

  local content_type
  local is_json = Json.parse(request.body) or (#request.inlined_files > 0 and request.inlined_files[1]:match("%.json$"))
  local is_csv = #request.inlined_files > 0 and request.inlined_files[1]:match("%.csv$")
  local is_form = request.body:match(".+=.+")

  if is_json then
    content_type = "application/json"
  elseif is_csv then
    content_type = "text/csv"
  elseif is_form then
    content_type = "application/x-www-form-urlencoded"
  end

  if content_type then request.headers["Content-Type"] = content_type end
end

local function parse_url(request, line)
  local method, http_version

  method = line:match("^([A-Z]+).+")

  if method then line = line:gsub("^" .. method .. "%s+", "") end
  if method == "GRPC" then return method, line end

  method = method or "GET"

  http_version = line:match("HTTP/(%d[.%d]*)")
  if http_version then line = line:gsub("%s*HTTP/" .. http_version .. "%s*", "") end

  if line == "*" then
    request.request_target = "*"
    line = ""
  end

  return method, line, http_version
end

local function parse_request_urL_method(request, line, lnum)
  request.method, request.url, request.http_version = parse_url(request, line)
  request.name = request.name or (request.method or "") .. " " .. (request.url or "")
  request.show_icon_line_number = lnum
end

local function parse_multiline_url(request, line)
  local path = line:match("^%s*(/.+)$")
  if request.url and path then request.url = request.url .. path end
end

local imports = {}

local function import_requests(path, request, lnum)
  path = FS.get_file_path(path, request.file)

  local file = FS.read_file(path)
  if not file then
    local msg = "The file '" .. path .. "' was not found."

    Diagnostics.add_diagnostics(DB.get_current_buffer(), msg, vim.diagnostic.WARN, lnum - 2, 0, lnum - 2, #path)
    return Logger.warn(msg)
  end

  local requests
  imports[tostring(request)] = true

  if vim.tbl_count(imports) < 10 then
    requests = parse_document(vim.split(file, "\n"), path)
  else
    Logger.warn("More than 10 nested run/imports detected, skipping, to prevent infinite loop")
  end

  imports[tostring(request)] = nil

  return requests
end

local function parse_import_command(request, imported_requests, line, lnum)
  local path = line:match("^import (.+)%s*") or ""
  if not path:match("%.http$") then return end

  local _requests = import_requests(path, request, lnum) or {}

  if #_requests > 0 then
    local imported_vars = vim.tbl_extend("keep", _requests[1].shared.variables or {}, _requests[1].variables or {})

    request.shared.variables = vim.tbl_extend("keep", request.shared.variables, imported_vars)

    vim.iter(_requests):each(function(r)
      _ = is_runnable(r) and table.insert(imported_requests, r)
    end)
  end
end

local function parse_run_command(requests, imported_requests, request, line, lnum)
  local variables_to_replace = line:match("^run .+%((@.+)%)%s*$")
  if variables_to_replace then line = line:gsub("%s*%(" .. variables_to_replace .. "%)%s*", "") end

  local path = line:gsub("^run ", "")
  local _requests = {}

  if path:match("^#") then
    _requests = vim.list_extend(vim.deepcopy(requests), imported_requests)

    local _request = vim.iter(_requests):find(function(_request)
      return _request.name == path:sub(2)
    end)

    _requests = { _request }
  elseif path:match("%.http$") then
    _requests = import_requests(path, request, lnum) or {}

    if #_requests > 0 then
      local imported_vars = vim.tbl_extend("keep", _requests[1].shared.variables or {}, _requests[1].variables or {})
      request.shared.variables = vim.tbl_extend("keep", request.shared.variables, imported_vars)
    end
  end

  vim.iter(_requests):each(function(_request)
    if not is_runnable(_request) then return end

    _request.show_icon_line_number = lnum

    vim.iter(vim.split(variables_to_replace or "", ",%s*")):each(function(variable)
      parse_variables(_request, variable)
    end)

    table.insert(request.nested_requests, _request)
  end)
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

---Parses given lines or DB.current_buffer document
---returns a list of DocumentRequests, imported DocumentRequests or nil if no valid requests found
---@param lines string[]|nil
---@param path string|nil
---@return DocumentRequest[]|nil, DocumentRequest[]|nil
function parse_document(lines, path)
  local buf = DB.get_current_buffer()
  if not path then Diagnostics.clear_diagnostics(buf, "parser") end

  local content_lines, line_offset = get_visual_selection() -- first: try to get the visual selection

  if not content_lines and FS.is_non_http_file() then -- second: try to get the content from the fenced block if the file is not an HTTP file
    content_lines, line_offset = get_request_from_fenced_code_block()

    content_lines = content_lines or { vim.fn.getline(".") } -- third: try to get the current line
    line_offset = line_offset or vim.fn.line(".")
  end

  content_lines = FS.is_non_http_file() and PARSER_UTILS.strip_invalid_chars(content_lines or {}) or content_lines

  content_lines = lines or content_lines or vim.api.nvim_buf_get_lines(buf, 0, -1, false) -- finally: get the whole buffer if the three methods above failed
  line_offset = line_offset or 0

  if not content_lines then return end

  local shared = vim.deepcopy(default_document_request)
  shared.url = nil

  local requests = {}
  local imported_requests = {}
  local blocks = split_content_by_blocks(content_lines, line_offset)

  for _, block in ipairs(blocks) do
    local is_request_line = true
    local is_prerequest_handler_script_inline = false
    local is_postrequest_handler_script_inline = false
    local is_body_section = false

    local request = vim.deepcopy(default_document_request)

    request.start_line = block.start_lnum
    request.end_line = block.end_lnum
    request.name = block.name
    request.file = path or vim.fn.fnamemodify(vim.fn.bufname(DB.get_current_buffer()), ":p")
    request.shared = shared

    for relative_linenr, line in ipairs(block.lines) do
      local lnum = request.start_line + relative_linenr

      if line:match("^# @") then
        parse_metadata(request, line)
        -- collect comments
      elseif not is_body_section and (line:match("^%s*#") or line:match("^%s*//")) then
        local comment = line:gsub("^%s*[#/]+%s*", "")
        table.insert(request.comments, comment)
      -- end of inline scripting
      elseif is_request_line and line:match("^import ") then
        parse_import_command(request, imported_requests, line, lnum)
      elseif is_request_line and line:match("^run ") then
        parse_run_command(requests, imported_requests, request, line, lnum)
      elseif is_request_line and line:match("^%%}$") then
        is_prerequest_handler_script_inline = false
      -- end of inline scripting
      elseif is_body_section and line:match("^%%}$") then
        is_postrequest_handler_script_inline = false
      -- inline scripting active: add the line to the response handler scripts
      elseif is_postrequest_handler_script_inline then
        request.scripts.post_request.priority = request.scripts.post_request.priority or "inline"
        table.insert(request.scripts.post_request.inline, line)
      -- inline scripting active: add the line to the prerequest handler scripts
      elseif is_prerequest_handler_script_inline then
        request.scripts.pre_request.priority = request.scripts.pre_request.priority or "inline"
        table.insert(request.scripts.pre_request.inline, line)
        -- we're still in(/before) the request line and we have a pre-request inline handler script
      elseif is_request_line and line:match("^< %{%%$") then
        is_prerequest_handler_script_inline = true
        -- we're still in(/before) the request line and we have a pre-request file handler script
      elseif is_request_line and line:match("^< (.*)$") then
        request.scripts.pre_request.priority = request.scripts.pre_request.priority or "files"
        local scriptfile = line:match("^< (.*)$")
        table.insert(request.scripts.pre_request.files, M.expand_included_filepath(scriptfile, lnum, request.file))
      elseif line == "" and not is_body_section then
        if not is_request_line then is_body_section = true end
        -- redirect response body to file
      elseif line:match("^>>(!?) (.*)$") then
        parse_redirect_response(request, line)
        -- start of inline scripting
      elseif line:match("^> {%%$") then
        is_postrequest_handler_script_inline = true
        -- file scripting notation
      elseif line:match("^> (.*)$") then
        request.scripts.post_request.priority = request.scripts.post_request.priority or "files"
        local scriptfile = line:match("^> (.*)$")
        table.insert(request.scripts.post_request.files, M.expand_included_filepath(scriptfile, lnum, request.file))
      elseif line:match("^@([%w_-]+)") then
        parse_variables(request, line)
      elseif is_body_section then
        parse_body(request, line, lnum)
      elseif not is_request_line and line:match("^%s*/.+") then
        parse_multiline_url(request, line)
      elseif not is_request_line and line:match("^%s*[?&]") and #request.headers == 0 and request.url then
        parse_query_params(request, line)
      elseif line:match("^([^%[%s]+):%s*(.*)$") and not line:match("^[^:]+:[/%d]+.+") and not line:match("%?") then
        -- skip [:] ipv6, ://, scheme, :80 port
        parse_headers(request, line)
        is_request_line = false
      elseif is_request_line then
        parse_request_urL_method(request, line, lnum)
        is_request_line = false
      end
    end

    if request.body then
      request.body = vim.trim(request.body)
      request.body_display = vim.trim(request.body_display)
      infer_headers_from_body(request)
    end

    if request.name == "Shared" or request.name == "Shared each" then
      shared = request
      shared.url = #shared.url > 0 and shared.url ~= "NOP" and shared.url or nil
    elseif request.url and #request.url + #request.request_target > 0 then
      table.insert(requests, request)
    elseif #request.nested_requests > 0 then
      vim.iter(request.nested_requests or {}):each(function(r)
        r.metadata = vim.tbl_extend("force", r.metadata, request.metadata)
        r.start_line, r.end_line = request.start_line, request.end_line
      end)
      vim.list_extend(requests, request.nested_requests)
    end
  end

  if #requests == 0 and is_runnable(shared) then table.insert(requests, shared) end

  local has_shared_data = vim.tbl_count(shared.variables) > 0
    or vim.tbl_count(shared.metadata) > 0
    or vim.tbl_count(shared.headers) > 0

  if #requests == 0 and has_shared_data then table.insert(requests, shared) end -- so shared data is available when importing variables only blocks

  return requests, imported_requests
end

---Parses given lines or DB.current_buffer document
---returns a list of DocumentRequests, imported DocumentRequests or nil if no valid requests found
---@param lines string[]|nil
---@param path string|nil
---@return DocumentRequest[]|nil, DocumentRequest[]|nil
M.get_document = function(lines, path)
  local status, result = xpcall(function()
    return { parse_document(lines, path) }
  end, debug.traceback, lines, path)

  if not status then return Logger.error(("Errors parsing the document: %s"):format(result), 1, { report = true }) end

  ---@diagnostic disable-next-line: redundant-return-value
  return unpack(result)
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

  return request
end

local function expand_nested_requests(requests, lnum)
  requests = vim.islist(requests) and requests or { requests }

  local expanded = {}
  local shared = requests[1].shared

  if not requests[1].name:match("^Shared") and is_runnable(shared) then
    if shared.name == "Shared each" then
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
    :filter(function(_request)
      return (request_name and _request.name == request_name)
        or (file and vim.fn.fnamemodify(_request.file, ":t") == file)
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
    if not request.name:match("^Shared") and is_runnable(shared) then table.insert(requests, 1, shared) end

    request = vim.iter(requests):find(function(_request)
      return linenr >= _request.start_line and linenr <= _request.end_line
    end)

    if not request then return {} end

    local line = vim.fn.getline(linenr)
    if line:match("^run") then
      local nested = get_run_requests(request, line)

      -- the case when block has no url, but only run commands and nested requests have been already expanded in parse_document()
      if #nested == 0 and #request.nested_requests == 0 then
        nested = vim
          .iter(requests)
          :filter(function(_request)
            return _request.start_line == request.start_line
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
