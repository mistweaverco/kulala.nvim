---@diagnostic disable: inject-field
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local FS = require("kulala.utils.fs")
local DOCUMENT_PARSER = require("kulala.parser.document")
local REQUEST_PARSER = require("kulala.parser.request")
local EXT_PROCESSING = require("kulala.external_processing")
local INT_PROCESSING = require("kulala.internal_processing")
local INLAY = require("kulala.inlay")
local Api = require("kulala.api")
local UiHighlight = require("kulala.ui.highlight")
local Logger = require("kulala.logger")

local M = {}

local TASK_QUEUE = {}
local RUNNING_TASK = false

local reset_task_queue = function()
  TASK_QUEUE = {} -- Clear the task queue and stop processing
  RUNNING_TASK = false
end

local function run_next_task()
  if #TASK_QUEUE == 0 then
    return reset_task_queue()
  end

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

local function offload_task(fn, callback)
  table.insert(TASK_QUEUE, { fn = fn, callback = callback })
  -- If no task is currently running, start processing
  if not RUNNING_TASK then
    run_next_task()
  end
end

local function process_prompt_vars(res)
  for _, metadata in ipairs(res.metadata) do
    if metadata.name == "prompt" and not INT_PROCESSING.prompt_var(metadata.value) then
      return false
    end
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

local function process_external(result)
  REQUEST_PARSER.scripts.javascript.run("post_request", result.scripts.post_request)
end

local function process_api()
  Api.trigger("after_next_request")
  Api.trigger("after_request")
end

local function save_response(request_status, parsed_request)
  local buf = DB.get_current_buffer()
  local line = parsed_request.show_icon_line_number or 0
  local id = buf .. ":" .. line

  local responses = DB.global_update().responses
  if #responses > 0 and responses[#responses].id == id and responses[#responses].status == -1 then
    table.remove(responses) -- remove the last response if it's the same request and status was unfinished
  end

  table.insert(responses, {
    id = id,
    url = parsed_request.url or "",
    method = parsed_request.method or "",
    status = request_status.code or 0,
    duration = request_status.duration or 0,
    body = FS.read_file(GLOBALS.BODY_FILE) or "",
    headers = FS.read_file(GLOBALS.HEADERS_FILE) or "",
    errors = request_status.errors or "",
    stats = request_status.stdout or "",
    script_pre_output = FS.read_file(GLOBALS.SCRIPT_PRE_OUTPUT_FILE) or "",
    script_post_output = FS.read_file(GLOBALS.SCRIPT_POST_OUTPUT_FILE) or "",
    buf = buf,
    buf_name = vim.fn.bufname(buf),
    line = line,
  })
end

local function process_response(request_status, parsed_request)
  process_metadata(parsed_request)
  process_internal(parsed_request)
  process_external(parsed_request)
  process_api()

  save_response(request_status, parsed_request)
end

local function process_errors(request, request_status, processing_errors)
  if request_status.code == 124 then
    request_status.errors = ("%s\nRequest timed out (%s ms)"):format(
      request_status.errors or "",
      CONFIG.get().request_timeout or ""
    )
  end

  local message = ("Errors in request %s at line: %s\n%s\n%s"):format(
    request.url,
    request.show_icon_line_number or "-",
    request_status.errors or "",
    processing_errors or ""
  )
  Logger.error(message)
end

local function handle_response(request_status, parsed_request, callback)
  local success = request_status.code == 0

  local status, processing_errors = xpcall(function()
    _ = success and process_response(request_status, parsed_request)
    -- TODO: add handling of potential errors during process_response and call callback with success=false
    callback(success, request_status.duration, parsed_request.show_icon_line_number)
  end, debug.traceback)

  if success and status then
    run_next_task()
  else
    process_errors(parsed_request, request_status, processing_errors)
    reset_task_queue()
  end
end

local function received_unbffured(request, response)
  local unbuffered = vim.tbl_contains(request.cmd, "-N")
  return unbuffered and response:find("Connected") and FS.file_exists(GLOBALS.BODY_FILE)
end

---Executes DocumentRequest
---@param requests DocumentRequest[]
---@param request DocumentRequest
---@param variables? DocumentVariables|nil
---@param callback function
local function process_request(requests, request, variables, callback)
  --  to allow running fastAPI within vim.system callbacks
  handle_response = vim.schedule_wrap(handle_response)

  FS.delete_request_scripts_files()
  FS.delete_cached_files(true)

  if not process_prompt_vars(request) then
    Logger.warn("Prompt failed. Skipping this and all following requests.")
    return
  end

  local parsed_request = REQUEST_PARSER.parse(requests, variables, request.start_line)
  if not parsed_request then
    Logger.warn(("Request at line: %s could not be parsed"):format(request.start_line))
    return
  end

  --TODO: call callback with success=false if promt fails or request could not be parsed

  local start_time = vim.uv.hrtime()
  local errors

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
---or runs all requests in the document
---@param requests? DocumentRequest[]|nil
---@param line_nr? number|nil
---@param callback function
---@return nil
M.run_parser = function(requests, line_nr, callback)
  local variables, reqs_to_process

  reset_task_queue()

  if not requests then
    variables, requests = DOCUMENT_PARSER.get_document()
  end

  if not requests then
    return Logger.error("No requests found in the document")
  end

  if line_nr and line_nr > 0 then
    local request = DOCUMENT_PARSER.get_request_at(requests, line_nr)
    if not request then
      return Logger.error("No request found at current line")
    end

    reqs_to_process = { request }
  end

  reqs_to_process = reqs_to_process or requests

  for _, req in ipairs(reqs_to_process) do
    INLAY.show("loading", req.show_icon_line_number)

    offload_task(function()
      UiHighlight.highlight_request(req)
      process_request(requests, req, variables, callback)
    end)
  end
end

return M
