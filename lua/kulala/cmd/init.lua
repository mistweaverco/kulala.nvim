local GLOBALS = require("kulala.globals")
local Fs = require("kulala.utils.fs")
local PARSER = require("kulala.parser")
local EXT_PROCESSING = require("kulala.external_processing")
local INT_PROCESSING = require("kulala.internal_processing")
local Api = require("kulala.api")
local INLAY = require("kulala.inlay")
local Logger = require("kulala.logger")
local UiHighlight = require("kulala.ui.highlight")

local M = {}

local TASK_QUEUE = {}
local RUNNING_TASK = false

local function run_next_task()
  if #TASK_QUEUE > 0 then
    RUNNING_TASK = true
    local task = table.remove(TASK_QUEUE, 1)

    ---@diagnostic disable-next-line: undefined-field
    vim.uv.new_timer():start(0, 0, function()
      vim.schedule(function()
        local status, res = xpcall(task.fn, debug.traceback)

        local cb_status, cb_res = true, ""
        if task.callback then
          cb_status, res = xpcall(task.callback, debug.traceback) -- Execute the callback in the main thread
        end

        if not (status and res and cb_status) then
          TASK_QUEUE = {} -- Clear the task queue and
          RUNNING_TASK = false

          Logger.error(("Errors running a scheduled task: %s %s"):format(res or "", cb_res or ""))
          return
        end

        RUNNING_TASK = false
        run_next_task() -- Proceed to the next task in the queue
      end)
    end)
  end
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
  local body = Fs.read_file(GLOBALS.BODY_FILE)

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
  PARSER.scripts.javascript.run("post_request", result.scripts.post_request)
  Fs.delete_request_scripts_files()
end

local function process_api()
  Api.trigger("after_next_request")
  Api.trigger("after_request")
end

local function process_response(request_status, parsed_request, callback)
  local success = request_status.code == 0

  if success then
    Fs.write_file(GLOBALS.STATS_FILE, request_status.stdout, false)
    Fs.write_file(GLOBALS.ERRORS_FILE, request_status.errors or "", false)

    process_metadata(parsed_request)
    process_internal(parsed_request)
    process_external(parsed_request)
    process_api()
  else
    local message = ("Errors in request %s at line: %s\n%s"):format(
      parsed_request.url,
      parsed_request.start_line,
      request_status.errors or ""
    )
    Logger.error(message)
  end

  callback(success, request_status.start_time, parsed_request.show_icon_line_number)
end

---Executes DocumentRequest
---@param requests DocumentRequest[]
---@param request DocumentRequest
---@param variables? DocumentVariables|nil
---@param callback function
local function process_request(requests, request, variables, callback)
  offload_task(function()
    if not process_prompt_vars(request) then
      Logger.warn("Prompt failed. Skipping this and all following requests.")
      return
    end

    local parsed_request = PARSER.parse(requests, variables, request.start_line)
    if not parsed_request then
      Logger.warn(("Request at line: %s could not be parsed"):format(request.start_line))
      return
    end

    ---@diagnostic disable-next-line: undefined-field
    local start_time = vim.loop.hrtime()
    local unbuffered = vim.tbl_contains(parsed_request.cmd, "-N")
    local errors

    local request_job = vim.system(parsed_request.cmd, {
      text = true,
      stderr = function(_, data)
        if data then
          errors = (errors or "") .. data

          if unbuffered and errors:find("Connected") and Fs.file_exists(GLOBALS.BODY_FILE) then
            vim.schedule(function()
              callback(nil, start_time, parsed_request.show_icon_line_number)
            end)
          end
        end
      end,
    }, function(job_status)
      ---@diagnostic disable-next-line: inject-field
      job_status.start_time = start_time
      ---@diagnostic disable-next-line: inject-field
      job_status.errors = errors

      vim.schedule(function()
        process_response(job_status, parsed_request, callback)
      end)
    end)

    if not unbuffered then
      request_job:wait()
    end

    return true
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
  Fs.clear_cached_files(true)

  if not requests then
    variables, requests = PARSER.get_document()
  end

  if not requests then
    return Logger.error("No requests found in the document")
  end

  if line_nr and line_nr > 0 then
    local request = PARSER.get_request_at(requests, line_nr)
    if not request then
      return Logger.error("No request found at current line")
    end

    reqs_to_process = { request }
  end

  reqs_to_process = reqs_to_process or requests

  for _, req in ipairs(reqs_to_process) do
    --- create namespace
    local ns = vim.api.nvim_create_namespace("kulala_requests_flash")
    INLAY:show_loading(req.show_icon_line_number)
    if req.start_line and req.end_line then
      UiHighlight.highlight_range(
        0,
        { row = req.start_line, col = 0 },
        { row = req.end_line, col = 0 },
        ns,
        100,
        function()
          process_request(requests, req, variables, callback)
        end
      )
    else
      process_request(requests, req, variables, callback)
    end
  end
end

return M
