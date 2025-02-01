local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local Fs = require("kulala.utils.fs")
local PARSER = require("kulala.parser")
local EXT_PROCESSING = require("kulala.external_processing")
local INT_PROCESSING = require("kulala.internal_processing")
local Api = require("kulala.api")
local INLAY = require("kulala.inlay")
local UV = vim.loop
local Logger = require("kulala.logger")

local M = {}

local TASK_QUEUE = {}
local RUNNING_TASK = false

local function run_next_task()
  if #TASK_QUEUE > 0 then
    RUNNING_TASK = true
    local task = table.remove(TASK_QUEUE, 1)

    UV.new_timer():start(0, 0, function()
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
  local success = true
  for _, metadata in ipairs(res.metadata) do
    if metadata then
      if metadata.name == "prompt" then
        local r = INT_PROCESSING.prompt_var(metadata.value)
        if not r then
          success = false
        end
      end
    end
  end
  return success
end

---Runs the command and returns the result
---@param cmd table command to run
---@param callback function|nil callback function
M.run = function(cmd, callback)
  vim.fn.jobstart(cmd, {
    on_stderr = function(_, datalist)
      if callback then
        callback(false, datalist)
      end
    end,
    on_exit = function(_, code)
      local success = code == 0
      if callback then
        callback(success, nil)
      end
    end,
  })
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

local function process_external(result)
  INT_PROCESSING.redirect_response_body_to_file(result.redirect_response_body_to_files)
  PARSER.scripts.javascript.run("post_request", result.scripts.post_request)
  Fs.delete_request_scripts_files()
end

local function process_api()
  Api.trigger("after_next_request")
  Api.trigger("after_request")
end

local function process_request(requests, request, variables, callback)
  local verbose_mode = CONFIG.get().default_view == "verbose"
  local unbuffered_mode

  offload_task(function()
    if not process_prompt_vars(request) then
      Logger.warn("Prompt failed. Skipping this and all following requests.")
      return false
    end

    local result = PARSER.parse(requests, variables, request.start_line)
    if not result then
      Logger.warn(("Request at line: %s could not be parsed"):format(request.start_line))
      return false
    end

    local icon_linenr = result.show_icon_line_number
    local start_time = vim.loop.hrtime()

    INLAY:show_loading(icon_linenr)

    local success, errors = false, nil
    local stats = vim
      .system(result.cmd, {
        text = true,
        stderr = function(_, data)
          if data then
            errors = (errors or "") .. data
          end
        end,
      }, function(data)
        success = data.code == 0
      end)
      :wait()

    if success then
      Fs.write_file(GLOBALS.STATS_FILE, vim.fn.json_encode(stats), false)
      if verbose_mode and errors then
        Fs.write_file(GLOBALS.ERRORS_FILE, errors, false)
      end

      process_metadata(result)
      process_external(result)
      process_api()
    else
      Logger.error(("Errors in request %s at line: %s\n%s"):format(request.url, request.start_line, errors or ""))
    end

    if callback then
      return callback(success, start_time, icon_linenr)
    end

    return true
  end)
end

---Runs the parser and returns the result
M.run_parser = function(requests, request, variables, callback)
  Fs.clear_cached_files(true)

  local reqs_to_process = request and { request } or requests

  for _, req in ipairs(reqs_to_process) do
    process_request(requests, req, variables, callback)
  end
end

return M
