local DB = require("kulala.db")
local FS = require("kulala.utils.fs")
local PARSER_UTILS = require("kulala.parser.utils")
local Logger = require("kulala.logger")

local M = {}

---@class Scripts
---@field pre_request ScriptData
---@field post_request ScriptData

---@class ScriptData
---@field inline string[]
---@field files string[]

---@class DocumentRequest
---@field headers table<string, string>
---@field headers_raw table<string, string>
---@field metadata table<{name: string, value: string}>
---@field body string
---@field body_display string
---@field start_line number
---@field end_line number
---@field show_icon_line_number number
---@field block_line_count number
---@field lines_length number
---@field variables DocumentVariables
---@field redirect_response_body_to_files ResponseBodyToFile[]
---@field scripts Scripts
---@field url string
---@field method string
---@field http_version string

---@alias DocumentVariables table<string, string|number|boolean>

---@class ResponseBodyToFile
---@field file string -- The file path to write the response body to
---@field overwrite boolean -- Whether to overwrite the file if it already exists

---@type DocumentRequest
local default_document_request = {
  headers = {},
  headers_raw = {},
  metadata = {},
  body = "",
  body_display = "",
  start_line = 0,
  end_line = 0,
  show_icon_line_number = 1,
  block_line_count = 0,
  lines_length = 0,
  variables = {},
  redirect_response_body_to_files = {},
  scripts = {
    pre_request = {
      inline = {},
      files = {},
    },
    post_request = {
      inline = {},
      files = {},
    },
  },
  url = "",
  http_version = "",
  method = "",
}

local function split_by_block_delimiters(text)
  local result = {}
  local start = 1
  -- Pattern to match lines starting with ### followed by optional text and ending with a newline
  local pattern = "\n###.-\n"
  while true do
    -- Find the next delimiter
    local split_start, split_end = text:find(pattern, start)
    if not split_start then
      -- If no more delimiters, add the remaining text as the last section
      local last_section = text:sub(start):gsub("\n+$", "") -- Remove trailing newlines

      if #last_section > 0 then
        table.insert(result, last_section)
      end
      break
    end
    -- Add the text before the delimiter as a section
    local section = text:sub(start, split_start - 1):gsub("\n+$", "") -- Remove trailing newlines
    if #section > 0 then
      table.insert(result, section)
    end
    -- Move start position
    start = split_end
  end

  return result
end

local function get_request_from_fenced_code_block()
  local buf = DB.get_current_buffer()
  local start_line = PARSER_UTILS.get_current_line_number()

  -- Get the total number of lines in the current buffer
  local total_lines = vim.api.nvim_buf_line_count(buf)

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
  if not block_start then
    return
  end

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
  if not block_end then
    return
  end

  return vim.api.nvim_buf_get_lines(buf, block_start, block_end - 1, false), block_start
end

local function get_visual_selection()
  local line_s, line_e

  if vim.api.nvim_get_mode().mode == "V" then
    vim.api.nvim_input("<Esc>")
  end
  line_s, line_e = vim.fn.getpos(".")[2], vim.fn.getpos("v")[2]

  if line_s > line_e then
    line_s, line_e = line_e, line_s
  end

  local contents = vim.api.nvim_buf_get_lines(DB.get_current_buffer(), line_s - 1, line_e, false)
  contents = PARSER_UTILS.strip_invalid_chars(contents)

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
    if meta_name and meta_value then
      table.insert(request.metadata, { name = meta_name, value = meta_value })
    end
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

  if line:find("^< ") then
    line = M.expand_included_filepath(line)
  elseif content_type:find("^application/x%-www%-form%-urlencoded") then
    -- should be no line endings or they should be urlencoded
    line_ending = ""
  elseif content_type:find("^multipart/form%-data") then
    -- per RFC2616 3.7.2. and RFC2046 5.1.1 multipart boundaries must end with \r\n
    line_ending = "\r\n"
  end

  request.body = request.body .. line .. line_ending
  request.body_display = request.body_display .. line .. line_ending
end

-- Request line (e.g., GET http://example.com HTTP/1.1)
-- Split the line into method, URL and HTTP version
-- HTTP Version is optional
local function parse_request_method(request, line, relative_linenr)
  request.method, request.url, request.http_version = line:match("^([A-Z]+)%s+(.+)%s+HTTP/(%d[.%d]*)%s*$")

  if not request.method then
    request.method, request.url = line:match("^([A-Z]+)%s+(.+)$")
  end

  request.show_icon_line_number = request.start_line + relative_linenr
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

---Parses the DB.current_buffer document and returns a list of DocumentRequests or nil if no valid requests found
---@return DocumentVariables|nil, DocumentRequest[]|nil
M.get_document = function()
  local buf = DB.get_current_buffer()

  local line_offset = 0
  local content_lines

  if FS.is_non_http_file() then
    content_lines, line_offset = get_request_from_fenced_code_block()

    if not content_lines then
      content_lines, line_offset = get_visual_selection()
    end
  end

  content_lines = content_lines or vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  if not content_lines then
    return
  end

  local content = table.concat(content_lines, "\n")
  local variables = {}
  local requests = {}
  local blocks = split_by_block_delimiters(content)

  for _, block in ipairs(blocks) do
    local is_request_line = true
    local is_prerequest_handler_script_inline = false
    local is_postrequest_handler_script_inline = false
    local is_body_section = false

    local lines = vim.split(block, "\n")
    local block_line_count = #lines

    local request = vim.deepcopy(default_document_request)

    request.start_line = line_offset + 1
    request.block_line_count = block_line_count
    request.lines_length = #lines

    for relative_linenr, line in ipairs(lines) do
      -- end of inline scripting
      if is_request_line and line:match("^%%}$") then
        is_prerequest_handler_script_inline = false
      -- end of inline scripting
      elseif is_body_section and line:match("^%%}$") then
        is_postrequest_handler_script_inline = false
      -- inline scripting active: add the line to the response handler scripts
      elseif is_postrequest_handler_script_inline then
        table.insert(request.scripts.post_request.inline, line)
      -- inline scripting active: add the line to the prerequest handler scripts
      elseif is_prerequest_handler_script_inline then
        table.insert(request.scripts.pre_request.inline, line)
      elseif line:sub(1, 1) == "#" then
        parse_metadata(request, line)
      -- we're still in(/before) the request line and we have a pre-request inline handler script
      elseif is_request_line and line:match("^< %{%%$") then
        is_prerequest_handler_script_inline = true
        -- we're still in(/before) the request line and we have a pre-request file handler script
      elseif is_request_line and line:match("^< (.*)$") then
        local scriptfile = line:match("^< (.*)$")
        table.insert(request.scripts.pre_request.files, scriptfile)
      elseif line == "" and not is_body_section then
        if not is_request_line then
          is_body_section = true
        end
        -- redirect response body to file
      elseif line:match("^>> (.*)$") then
        parse_redirect_response(request, line)
        -- start of inline scripting
      elseif line:match("^> {%%$") then
        is_postrequest_handler_script_inline = true
        -- file scripting notation
      elseif line:match("^> (.*)$") then
        local scriptfile = line:match("^> (.*)$")
        table.insert(request.scripts.post_request.files, scriptfile)
      elseif line:match("^@([%w_]+)") then
        parse_variables(variables, line)
      elseif is_body_section then
        parse_body(request, line)
      elseif not is_request_line and line:match("^%s*[?&]") and #request.headers == 0 and request.url then
        parse_query_params(request, line)
      elseif not is_request_line and line:match("^([^:]+):%s*(.*)$") then
        parse_headers(request, line)
      elseif is_request_line then
        parse_request_method(request, line, relative_linenr)
        is_request_line = false
      end
    end

    if request.body then
      request.body = vim.trim(request.body)
      request.body_display = vim.trim(request.body_display)
    end

    request.end_line = line_offset + block_line_count
    line_offset = request.end_line + 1 -- +1 for the '###' separator line

    table.insert(requests, request)
  end

  return variables, requests
end

---Returns a DocumentRequest within specified line number from a list of DocumentRequests
---or returns the first DocumentRequest in the list if no line number is provided
---@param requests DocumentRequest[]
---@param linenr? number|nil
---@return DocumentRequest|nil
M.get_request_at = function(requests, linenr)
  if not linenr then
    return requests[1]
  end

  for _, request in ipairs(requests) do
    if linenr >= request.start_line and linenr <= request.end_line then
      return request
    end
  end
end

M.get_previous_request = function(requests)
  local cursor_line = PARSER_UTILS.get_current_line_number()

  for i, request in ipairs(requests) do
    if i > 1 and cursor_line >= request.start_line and cursor_line <= request.end_line then
      return requests[i - 1]
    end
  end
end

M.get_next_request = function(requests)
  local cursor_line = PARSER_UTILS.get_current_line_number()

  for i, request in ipairs(requests) do
    if i < #requests and cursor_line >= request.start_line and cursor_line <= request.end_line then
      return requests[i + 1]
    end
  end
end

return M
