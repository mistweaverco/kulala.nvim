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
local Logger = require("kulala.logger")
local REQUEST_PARSER = require("kulala.parser.request")
local Scripts = require("kulala.parser.scripts")
local UI_utils = require("kulala.ui.utils")
local WS = require("kulala.cmd.websocket")

local M = {}

local TASK_QUEUE = {}
local RUNNING_TASK = false

local process_request

local function reset_task_queue()
  local db = DB.global_update()

  TASK_QUEUE = {} -- Clear the task queue and stop processing
  RUNNING_TASK = false

  db.requests_total = 0
  db.requests_done = 0
  db.requests_status = false

  return true
end

local function run_next_task()
  if #TASK_QUEUE == 0 then return reset_task_queue() end

  RUNNING_TASK = true
  local task = table.remove(TASK_QUEUE, 1)

  vim.schedule(function()
    local status, errors = xpcall(task.fn, debug.traceback)

    local cb_status, cb_errors = true, ""
    if task.callback then
      cb_status, cb_errors = xpcall(task.callback, debug.traceback)
    end

    if not (status and cb_status) then
      reset_task_queue()
      Logger.error(("Errors running a scheduled task: %s %s"):format(errors or "", cb_errors))
    end
  end)
end

local function offload_task(fn, pos, callback)
  pos = pos or #TASK_QUEUE + 1
  table.insert(TASK_QUEUE, { fn = fn, callback = callback })

  if not RUNNING_TASK then run_next_task() end
end

local function process_prompt_vars(res)
  for _, metadata in ipairs(res.metadata) do
    if metadata.name == "prompt" and not INT_PROCESSING.prompt_var(metadata.value) then return false end
  end

  return true
end

local function process_metadata(result)
  local body = FS.read_file(GLOBALS.BODY_FILE)

  local int_meta_processors = {
    ["name"] = "set_env_for_named_request",
    ["env-json-key"] = "env_json_key",
    ["env-header-key"] = "env_header_key",
  }

  local ext_meta_processors = {
    ["stdin-cmd"] = "stdin_cmd",
    ["env-stdin-cmd"] = "env_stdin_cmd",
  }

  local processor
  for _, metadata in ipairs(result.metadata) do
    processor = int_meta_processors[metadata.name]
    _ = processor and INT_PROCESSING[processor](metadata.value, body)

    processor = ext_meta_processors[metadata.name]
    _ = processor and EXT_PROCESSING[processor](metadata.value, body)
  end
end

local function process_internal(result)
  INT_PROCESSING.redirect_response_body_to_file(result.redirect_response_body_to_files)
end

local function process_external(request, response)
  _ = Scripts.run("post_request", request, response) and REQUEST_PARSER.process_variables(request, {}, true)

  response.script_pre_output = response.script_pre_output or FS.read_file(GLOBALS.SCRIPT_PRE_OUTPUT_FILE) or ""
  response.script_post_output = response.script_post_output or FS.read_file(GLOBALS.SCRIPT_POST_OUTPUT_FILE) or ""
  response.assert_output = response.assert_output or FS.read_json(GLOBALS.ASSERT_OUTPUT_FILE) or {}
  response.assert_status = response.assert_output.status
  response.status = response.status and response.assert_status ~= false

  return request.environment["__replay_request"] == "true"
end

local function process_api()
  Api.trigger("after_next_request")
  Api.trigger("after_request")
end

local function modify_grpc_response(response)
  if response.method ~= "GRPC" then return response end

  response.body = response.stats
  response.stats = ""
  response.headers = "Content-Type: application/json"

  return response
end

local function set_request_stats(response)
  local _, stats = pcall(vim.json.decode, response.stats, { object = true, array = true })

  response.stats = _ and stats or response.stats
  response.response_code = _ and tonumber(stats.response_code) or response.code
  response.status = response.code == 0 and response.response_code < 400

  return response
end

local function save_response(request_status, parsed_request)
  local buf = DB.get_current_buffer()
  local line = parsed_request.show_icon_line_number or 0
  local id = buf .. ":" .. line

  local responses = DB.global_update().responses
  if #responses > 0 and responses[#responses].id == id and responses[#responses].code == -1 then
    table.remove(responses) -- remove the last response if it's the same request and status was unfinished
  end

  local response = {
    id = id,
    name = parsed_request.name or "",
    url = parsed_request.url or "",
    method = parsed_request.method or "",
    code = request_status.code or -1,
    response_code = 0,
    status = false,
    time = vim.fn.localtime(),
    duration = request_status.duration or 0,
    body = FS.read_file(GLOBALS.BODY_FILE) or "",
    json = {},
    headers = FS.read_file(GLOBALS.HEADERS_FILE) or "",
    errors = request_status.errors or "",
    stats = request_status.stdout or "",
    assert_status = nil,
    file = parsed_request.file or "",
    buf_name = vim.fn.bufname(buf),
    line = line,
    buf = buf,
  }

  local status, result = pcall(vim.json.decode, response.body, { object = true, array = true })
  response.json = status and result or {}

  response = modify_grpc_response(response)
  response = set_request_stats(response)

  response.body = #response.body == 0 and "No response body (check Verbose output)" or response.body

  table.insert(responses, response)

  return response
end

local function process_response(request_status, parsed_request, callback)
  local db = DB.global_update()
  local response

  process_metadata(parsed_request)
  process_internal(parsed_request)

  response = save_response(request_status, parsed_request)

  if process_external(parsed_request, response) then -- replay request
    parsed_request.processed = true
    db.requests_total = db.requests_total + 1

    offload_task(function()
      process_request({ parsed_request }, parsed_request, {}, callback)
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
  _ = processing_errors and Logger.error(processing_errors, 2)

  request_status.errors = processing_errors and request_status.errors .. "\n" .. processing_errors
    or request_status.errors

  save_response(request_status, request)
end

local function handle_response(request_status, parsed_request, callback)
  local config = CONFIG.get()
  local db = DB.global_update()
  local code = request_status.code == 0
  local success

  local processing_status, processing_errors = xpcall(function()
    success = code and process_response(request_status, parsed_request, callback)
  end, debug.traceback)

  _ = not (code and processing_status) and process_errors(parsed_request, request_status, processing_errors)

  db.requests_done = db.requests_done + 1
  db.requests_status = db.requests_done < db.requests_total

  callback(success, request_status.duration, parsed_request.show_icon_line_number)
  _ = (not success and config.halt_on_error) and reset_task_queue() or run_next_task()
end

local function received_unbffured(request, response)
  local unbuffered = vim.tbl_contains(request.cmd, "-N")
  return unbuffered and response:find("Connected") and FS.file_exists(GLOBALS.BODY_FILE)
end

local function initialize()
  FS.delete_request_scripts_files()
  FS.delete_cached_files(true)
end

local function parse_request(requests, request, variables)
  initialize()

  if not process_prompt_vars(request) then
    return Logger.warn("Prompt failed. Skipping this and all following requests.")
  end

  local parsed_request, status = REQUEST_PARSER.parse(requests, variables, request)
  if not parsed_request then
    status = status == "skipped" and "is skipped" or "could not be parsed"
    return Logger.warn(("Request at line: %s " .. status):format(request.start_line))
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

  return callback(status, 0, response.line) and reset_task_queue()
end

---Executes DocumentRequest
---@param requests DocumentRequest[]
---@param request DocumentRequest
---@param variables? DocumentVariables|nil
---@param callback function
function process_request(requests, request, variables, callback)
  local config = CONFIG.get()
  --  to allow running fastAPI within vim.system callbacks
  handle_response = vim.schedule_wrap(handle_response)

  local parsed_request = parse_request(requests, request, variables)
  if not parsed_request then
    callback(false, 0, request.start_line)
    return config.halt_on_error and reset_task_queue() or run_next_task()
  end

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

---Parses and executes DocumentRequest/s:
---if requests are provied then runs the first request in the list
---if line_nr is provided then runs the request from current buffer within the line number
---if line_nr is 0, then runs visually selected requests
---or runs all requests in the document
---@param requests? DocumentRequest[]|nil
---@param line_nr? number|nil
---@param callback function
---@return nil
M.run_parser = function(requests, line_nr, callback)
  local db = DB.global_update()
  local variables, reqs_to_process

  reset_task_queue()

  if not requests then
    variables, requests = DOCUMENT_PARSER.get_document()
  end

  if not requests then return Logger.error("No requests found in the document") end

  if line_nr and line_nr > 0 then
    local requests_l = DOCUMENT_PARSER.get_request_at(requests, line_nr)
    if #requests_l == 0 then return Logger.error("No request found at current line") end

    reqs_to_process = requests_l
  end

  reqs_to_process = reqs_to_process or requests
  db.requests_total = #reqs_to_process
  db.requests_status = true

  for _, req in ipairs(reqs_to_process) do
    INLAY.show("loading", req.show_icon_line_number)

    offload_task(function()
      UI_utils.highlight_request(req)
      process_request(requests, req, variables, callback)
    end)
  end
end

M.reset_task_queue = reset_task_queue

return M
