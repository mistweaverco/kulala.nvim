---@diagnostic disable: inject-field
local Api = require("kulala.api")
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local DOCUMENT_PARSER = require("kulala.parser.document")
local EXT_PROCESSING = require("kulala.external_processing")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local INLAY = require("kulala.inlay")
local INT_PROCESSING = require("kulala.internal_processing")
local Json = require("kulala.utils.json")
local Logger = require("kulala.logger")
local REQUEST_PARSER = require("kulala.parser.request")
local Scripts = require("kulala.parser.scripts")
local UI_utils = require("kulala.ui.utils")
local WS = require("kulala.cmd.websocket")

local M = {}

local queue = {
  reset = function(self)
    self.status = "idle" -- "idle"|"running"|"paused"
    self.tasks = {}
    self.previous_task = nil
    self.total = 0 -- total number of tasks added to the queue
    self.done = 0 -- number of tasks done

    return self
  end,
  pause = function(self)
    self.status = "paused"
  end,
  resume = function(self)
    self.status = "idle"
    table.insert(self.tasks, 1, self.previous_task)
    self:run_next()
  end,
}

M.queue = queue:reset()

local process_request

---Add task to the queue
---@param self table
---@param data? any additional data to be passed to the task function
---@param fn function task function
---@param pos? number position in the queue (default: end of the queue)
---@param callback? function callback function to be called after the task is done
function queue.add(self, data, fn, pos, callback)
  pos = pos or #self.tasks + 1
  self.total = self.total + 1
  table.insert(self.tasks, pos, { fn = fn, callback = callback, data = data })
end

function queue.run_next(self)
  if #self.tasks == 0 or self.status == "paused" then return end

  local task = table.remove(self.tasks, 1)

  self.previous_task = task
  self.status = "running"

  vim.schedule(function()
    local status, errors = xpcall(task.fn, debug.traceback)

    local cb_status, cb_errors = true, ""
    if task.callback then
      cb_status, cb_errors = xpcall(task.callback, debug.traceback)
    end

    if not (status and cb_status) then
      self:reset()
      Logger.error(("Errors running a scheduled task: %s %s"):format(errors or "", cb_errors), 1, { report = true })
    end

    self.done = self.done + 1
  end)
end

local function initialize()
  FS.delete_request_scripts_files()
  FS.delete_cached_files(true)
end

local function process_prompt_vars(res)
  for _, metadata in ipairs(res.metadata) do
    local secret = metadata.name == "secret"

    if
      (metadata.name == "prompt" or secret)
      and not vim.g.kulala_cli
      and not INT_PROCESSING.prompt_var(metadata.value, secret)
    then
      return false
    end
  end

  return true
end

local function process_metadata(request, response)
  local int_meta_processors = {
    ["env-json-key"] = "env_json_key",
    ["env-header-key"] = "env_header_key",
  }

  local ext_meta_processors = {
    ["stdin-cmd"] = "stdin_cmd",
    ["env-stdin-cmd"] = "env_stdin_cmd",
    ["jq"] = "jq",
  }

  local processor
  for _, metadata in ipairs(request.metadata) do
    processor = int_meta_processors[metadata.name]
    _ = processor and INT_PROCESSING[processor](metadata.value, response)

    processor = ext_meta_processors[metadata.name]
    _ = processor and EXT_PROCESSING[processor](metadata.value, response)
  end
end

local function process_internal(result)
  INT_PROCESSING.redirect_response_body_to_file(result.redirect_response_body_to_files)
end

local function process_external(request, response)
  if Scripts.run("post_request", request, response) then REQUEST_PARSER.process_variables(request, true) end

  response.script_pre_output = FS.read_file(GLOBALS.SCRIPT_PRE_OUTPUT_FILE) or ""
  response.script_post_output = FS.read_file(GLOBALS.SCRIPT_POST_OUTPUT_FILE) or ""
  response.assert_output = FS.read_json(GLOBALS.ASSERT_OUTPUT_FILE) or {}

  response.assert_status = response.assert_output.status
  response.status = response.status and response.assert_status ~= false

  local replay = request.environment["__replay_request"] == "true"
  request.environment["__replay_request"] = nil

  return replay and "replay"
end

local function process_api()
  Api.trigger("after_next_request")
  Api.trigger("after_request")
end

local function add_content_type_header(response, content_type)
  response.headers = response.headers .. "Content-Type: " .. content_type .. "\n\n"
  response.headers_tbl = INT_PROCESSING.get_headers()
end

local function modify_grpc_response(response)
  if response.method ~= "GRPC" then return response end

  response.body_raw = response.stats
  response.stats = ""

  FS.write_file(GLOBALS.BODY_FILE, response.body_raw)

  local content_type = response.errors == "" and "application/json" or "kulala/grpc_error"
  add_content_type_header(response, content_type)

  return response
end

local function set_request_stats(response)
  response.stats = Json.parse(tostring(response.stats)) or {}
  response.response_code = tonumber(response.stats.response_code) or response.code
  response.status = response.code == 0 and response.response_code < 400
  response.assert_status = response.status and response.assert_status

  return response
end

local function inject_payload(errors, request)
  local lines = vim.split(errors, "\n")
  local lnum

  for i, line in ipairs(lines) do
    if line:find("^>") and not lines[i + 1]:find("^>") then
      lnum = i
      break
    end
  end

  lnum = lnum or #lines

  local body = FS.read_file(request.body_temp_file) or ""
  body = #body > 1000 and request.body or body

  _ = #vim.trim(body) > 0 and table.insert(lines, lnum + 1, "> Payload:\n\n" .. body .. "\n")

  return table.concat(lines, "\n")
end

local function truncate_body(response)
  local max_size = CONFIG.get().ui.max_response_size

  if vim.fn.getfsize(GLOBALS.BODY_FILE) > max_size then
    add_content_type_header(response, "text/plain")
    return "The size of response is > " .. max_size / 1024 .. "Kb.\nPath to response: " .. GLOBALS.BODY_FILE
  else
    return FS.read_file(GLOBALS.BODY_FILE) or ""
  end
end

local function save_response(request_status, parsed_request)
  local buf = DB.get_current_buffer()
  local line = parsed_request.show_icon_line_number or 0
  local id = buf .. ":" .. line

  local responses = DB.global_update().responses
  if #responses > 0 and responses[#responses].id == id and responses[#responses].code == -1 then
    table.remove(responses) -- remove the last response if it's the same request and status was unfinished (for chunked response)
  end

  ---@type Response
  local response = {
    id = id,
    name = parsed_request.name or "",
    url = parsed_request.url or "",
    method = parsed_request.method or "",
    request = {
      headers_tbl = parsed_request.headers,
      body = parsed_request.body,
    },
    code = request_status.code or -1,
    response_code = 0,
    status = false,
    time = vim.fn.localtime(),
    duration = request_status.duration or 0,
    body_raw = FS.read_file(GLOBALS.BODY_FILE) or "",
    body = "",
    json = {},
    filter = nil,
    headers = FS.read_file(GLOBALS.HEADERS_FILE) or "",
    headers_tbl = INT_PROCESSING.get_headers() or {},
    cookies = INT_PROCESSING.get_cookies() or {},
    errors = request_status.errors or "",
    stats = request_status.stdout or "",
    script_pre_output = "",
    script_post_output = "",
    assert_output = {},
    assert_status = true,
    file = parsed_request.file or "",
    buf_name = vim.fn.bufname(buf),
    line = line,
    buf = buf,
  }

  response = modify_grpc_response(response)
  response = set_request_stats(response)

  response.body = truncate_body(response)
  response.json = Json.parse(response.body) or {}
  response.errors = inject_payload(response.errors, parsed_request)

  if #response.body == 0 and response.method ~= "GRPC" then response.headers = "Content-Type: text/plain" end
  if #response.body == 0 then response.body = "No response body (check Verbose output)" end

  table.insert(responses, response)

  return response
end

local function process_response(request_status, parsed_request, callback)
  local response = save_response(request_status, parsed_request)

  process_metadata(parsed_request, response)
  process_internal(parsed_request)

  if process_external(parsed_request, response) == "replay" then
    M.queue:add({ request = parsed_request }, function()
      process_request({ parsed_request }, parsed_request, callback)
    end, 1)
  end

  process_api()

  return response.status
end

local function process_errors(request, request_status, processing_errors)
  if request_status.code == 124 then
    request_status.errors = ("%s\nRequest timed out (%s ms)"):format(
      request_status.errors or "",
      CONFIG.get().request_timeout or ""
    )
  end

  local message = ("Errors in request %s at line: %s\n%s"):format(
    request.url,
    request.show_icon_line_number or "-",
    request_status.errors or ""
  )

  Logger.error(message, 2)
  _ = processing_errors and Logger.error(processing_errors, 2, { report = true })

  request_status.errors = processing_errors and request_status.errors .. "\n" .. processing_errors
    or request_status.errors

  save_response(request_status, request)
end

local function handle_response(request_status, parsed_request, callback)
  local config = CONFIG.get()
  local code = request_status.code == 0
  local success

  local processing_status, processing_errors = xpcall(function()
    success = code and process_response(request_status, parsed_request, callback)
  end, debug.traceback)

  _ = not (code and processing_status) and process_errors(parsed_request, request_status, processing_errors)
  _ = (not success and config.halt_on_error) and M.queue:reset() or M.queue:run_next()

  callback(success, request_status.duration, parsed_request.show_icon_line_number)
end

local function received_unbffured(request, response)
  local unbuffered = vim.tbl_contains(request.cmd, "-N")
  return unbuffered and response:find("Connected") and FS.file_exists(GLOBALS.BODY_FILE)
end

local function process_pre_request_commands(request)
  if not process_prompt_vars(request) then
    return Logger.warn("Prompt failed. Skipping this and all following requests.")
  end

  local int_meta_processors = {
    ["delay"] = "delay",
  }

  local ext_meta_processors = {
    ["stdin-cmd-pre"] = "stdin_cmd",
    ["env-stdin-cmd-pre"] = "env_stdin_cmd",
  }

  local processor
  for _, metadata in ipairs(request.metadata) do
    processor = int_meta_processors[metadata.name]
    _ = processor and INT_PROCESSING[processor](metadata.value)
  end

  for _, metadata in ipairs(request.metadata) do
    processor = ext_meta_processors[metadata.name]
    _ = processor and EXT_PROCESSING[processor](metadata.value)
  end

  return true
end

local function parse_request(requests, request)
  if not process_pre_request_commands(request) then return end

  local parsed_request, status = REQUEST_PARSER.parse(requests, request)

  if not parsed_request then
    if status == "empty" then return status end

    local msg = status == "skipped" and "is skipped" or "could not be parsed"
    Logger.warn(("Request at line: %s " .. msg):format(request.start_line or request.show_icon_line_number))

    return status
  end

  return parsed_request
end

local function check_executable(cmd)
  local executable = cmd[1]
  if vim.fn.executable(executable) == 0 then
    return Logger.error(("Executable %s is not found or not executable"):format(executable))
  end

  return true
end

local function process_ws_request(request, callback)
  local response = save_response({ code = 0 }, request)
  local status = WS.connect(request, response, callback)

  response.code = status and 0 or -1
  response.status = status and true or false

  return callback(status, 0, response.line) and M.queue:reset()
end

---Executes DocumentRequest
---@param requests DocumentRequest[]
---@param request DocumentRequest
---@param callback function
function process_request(requests, request, callback)
  local config = CONFIG.get()
  --  to allow running fastAPI within vim.system callbacks
  handle_response = vim.schedule_wrap(handle_response)

  local parsed_request = parse_request(requests, request)

  if parsed_request == "empty" or parsed_request == "skipped" then return M.queue:run_next() end
  if not parsed_request then
    callback(false, 0, request.start_line)
    return config.halt_on_error and M.queue:reset() or M.queue:run_next()
  end

  if M.queue.status == "paused" then return end

  local start_time = vim.uv.hrtime()
  local errors

  if not check_executable(parsed_request.cmd) then return callback(false, 0, parsed_request.show_icon_line_number) end

  if parsed_request.method == "WS" or parsed_request.method == "WEBSOCKET" then
    return process_ws_request(parsed_request, callback)
  end

  vim.system(parsed_request.cmd, {
    text = true,
    timeout = CONFIG.get().request_timeout,
    stderr = function(_, data)
      if data then
        errors = (errors or "") .. data:gsub("\r\n", "\n")

        if received_unbffured(parsed_request, errors) then
          vim.schedule(function()
            save_response({ code = -1 }, parsed_request)
            callback(nil, 0, parsed_request.show_icon_line_number)
          end)
        end
      end
    end,
  }, function(job_status)
    job_status.errors = errors
    job_status.duration = vim.uv.hrtime() - start_time

    handle_response(job_status, parsed_request, callback)
  end)
end

---@param request DocumentRequest
---@return boolean
local function execute_before_request(request)
  local before_request = CONFIG.get().before_request
  if not before_request then return true end

  if type(before_request) == "function" then
    return before_request(request)
  else
    UI_utils.highlight_request(request)
    return true
  end
end

---Parses and executes DocumentRequest/s:
---if requests is nil then it parses the current document
---if line_nr is nil then runs the first request in the list (used for replaying last request)
---if line_nr > 0 then runs the request from current buffer around the line number
---if line_nr is 0 then runs all or visually selected requests
---@param requests? DocumentRequest[]|nil
---@param line_nr? number|nil
---@param callback function
M.run_parser = function(requests, line_nr, callback)
  M.queue:reset()

  if not requests then requests = DOCUMENT_PARSER.get_document() end
  if not requests then return Logger.error("No requests found in the document") end

  requests = DOCUMENT_PARSER.get_request_at(requests, line_nr)
  if #requests == 0 then return Logger.error("No request found at current line") end

  for _, request in ipairs(requests) do
    INLAY.show(DB.current_buffer, "loading", request.show_icon_line_number)

    M.queue:add({ request = request }, function()
      if execute_before_request(request) then
        initialize()
        process_request(requests, request, callback)
      end
    end)
  end

  M.queue:run_next()
end

return M
