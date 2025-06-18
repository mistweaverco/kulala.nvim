local DB = require("kulala.db")
local FS = require("kulala.utils.fs")
local Logger = require("kulala.logger")
local PARSER_UTILS = require("kulala.parser.utils")
local Table = require("kulala.utils.table")

local M = {}

---@class DocumentRequest
---@field metadata table<{name: string, value: string}>
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
  metadata = {},
  comments = {},
  method = "",
  url = "",
  request_target = nil,
  http_version = "",
  headers = {},
  headers_raw = {},
  cookie = "",
  body = "",
  body_display = "",
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

local function split_content_by_blocks(lines, line_offset)
  local new_block = { lines = {}, name = nil, start_lnum = math.max(1, line_offset), end_lnum = 1 }
  local delimiter = "###"
  local blocks = {}

  local block = vim.deepcopy(new_block)

  for lnum, line in ipairs(lines) do
    local is_delimiter = line:match("^" .. delimiter)

    if is_delimiter or lnum == #lines then
      if lnum == #lines then
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

-- Variable
-- Variables are defined as `@variable_name=value`
-- The value can be a string, a number or boolean
local function parse_variables(variables, line)
  local variable_name, variable_value = line:match("^@([%w_]+)%s*=%s*(.*)$")
  if variable_name and variable_value then
    -- remove the @ symbol from the variable name
    variable_name = variable_name:sub(1)
    variables[variable_name] = variable_value
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

local function parse_body(request, line)
  request.body = request.body or ""
  request.body_display = request.body_display or ""

  local line_ending = "\n"
  local _, content_type = PARSER_UTILS.get_header(request.headers, "content-type")
  content_type = content_type or ""

  if line:find("^< [^{]") then
    line = M.expand_included_filepath(line)
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

local function parse_host(request, line)
  line = line:gsub("^Host:%s*", "")
  request.url = (request.url == "" or request.url:match("^/")) and (line .. request.url) or request.url
end

local function parse_request_urL_method(request, line, relative_linenr)
  request.method, request.url, request.http_version = parse_url(request, line)
  request.name = request.name or (request.method or "") .. " " .. (request.url or "")
  request.show_icon_line_number = request.start_line + relative_linenr
end

local function parse_multiline_url(request, line)
  local path = line:match("^%s*(/%w+)$")
  if request.url and path then request.url = request.url .. path end
end

local function import_requests(path, variables, request)
  path = FS.get_file_path(path, request.file)

  local file = FS.read_file(path)
  if not file then return Logger.warn("The file '" .. path .. "' was not found. Skipping ...") end

  local r_variables, requests = M.get_document(vim.split(file, "\n"), path)
  Table.merge("keep", variables, r_variables)

  return requests
end

local function parse_import_command(variables, request, imported_requests, line)
  local path = line:match("^import (.+)%s*") or ""
  if not path:match("%.http$") then return end

  vim.list_extend(imported_requests, import_requests(path, variables, request) or {})
end

local function parse_run_command(requests, imported_requests, variables, request, line, lnum)
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
    _requests = import_requests(path, variables, request) or {}
  end

  vim.iter(_requests):each(function(_request)
    _request.show_icon_line_number = lnum
    table.insert(request.nested_requests, _request)
  end)

  vim.iter(vim.split(variables_to_replace or "", ",%s*")):each(function(variable)
    parse_variables(variables, variable)
  end)
end

-- expand path for included files, so can be used in request replay(), when cwd has changed
M.expand_included_filepath = function(line)
  local path = line:match("^< ([^\r\n]+)[\r\n]*$")
  path = path and FS.get_file_path(path)

  if FS.read_file(path, true) then
    line = "< " .. path
  else
    Logger.warn("The file '" .. path .. "' was not found. Skipping ...")
    line = "< [file not found] " .. path
  end

  return line
end

---Parses given lines or DB.current_buffer document
---returns a list of DocumentVariables, DocumentRequests, imported DocumentRequests or nil if no valid requests found
---@param lines string[]|nil
---@param path string|nil
---@return DocumentVariables|nil, DocumentRequest[]|nil, DocumentRequest[]|nil
M.get_document = function(lines, path)
  local buf = DB.get_current_buffer()

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

  local variables = {}
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

    for relative_linenr, line in ipairs(block.lines) do
      if line:match("^# @") then
        parse_metadata(request, line)
      -- collect comments
      elseif line:match("^%s*#") or line:match("^%s*//") then
        local comment = line:gsub("^%s*[#/]+%s*", "")
        table.insert(request.comments, comment)
      -- end of inline scripting
      elseif is_request_line and line:match("^import ") then
        parse_import_command(variables, request, imported_requests, line)
      elseif is_request_line and line:match("^run ") then
        parse_run_command(requests, imported_requests, variables, request, line, request.start_line + relative_linenr)
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
        table.insert(request.scripts.pre_request.files, scriptfile)
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
        table.insert(request.scripts.post_request.files, scriptfile)
      elseif line:match("^@([%w_]+)") then
        parse_variables(variables, line)
      elseif is_body_section then
        parse_body(request, line)
      elseif not is_request_line and line:match("^%s*/%a+") then
        parse_multiline_url(request, line)
      elseif not is_request_line and line:match("^%s*[?&]") and #request.headers == 0 and request.url then
        parse_query_params(request, line)
      elseif line:match("^Host:") then
        parse_host(request, line)
        is_request_line = false
      elseif line:match("^([^%[]+):%s*(.*)$") and not line:match("^[^:]+:[/%d]+.+") and not line:match("%?") then
        -- skip [:] ipv6, ://, scheme, :80 port
        parse_headers(request, line)
        is_request_line = false
      elseif is_request_line then
        parse_request_urL_method(request, line, relative_linenr)
        is_request_line = false
      end
    end

    if request.body then
      request.body = vim.trim(request.body)
      request.body_display = vim.trim(request.body_display)
    end

    if request.url and #request.url > 0 then
      table.insert(requests, request)
    elseif #request.nested_requests > 0 then
      vim.list_extend(requests, request.nested_requests)
    end
  end

  return variables, requests, imported_requests
end

local function expand_nested_requests(requests, lnum)
  requests = vim.islist(requests) and requests or { requests }

  local expanded = {}

  vim.iter(requests):each(function(request)
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
  if not linenr then return expand_nested_requests(requests[1]) end
  if linenr == 0 then return expand_nested_requests(requests) end

  local request = vim.iter(requests):find(function(_request)
    return linenr >= _request.start_line and linenr <= _request.end_line
  end)

  if not request then return {} end

  local line = vim.fn.getline(linenr)
  if line:match("^run") then return get_run_requests(request, line) end

  return expand_nested_requests(request)
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

return M
