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
        local res = task.fn() -- Execute the task in the main thread
        if res == false then
          RUNNING_TASK = false
          TASK_QUEUE = {} -- Clear the task queue and
          return
        end
        if task.callback then
          task.callback() -- Execute the callback in the main thread
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

---Runs the parser and returns the result
M.run_parser = function(requests, req, callback)
  local stats, errors
  local verbose_mode = CONFIG.get().default_view == "verbose"

  if process_prompt_vars(req) == false then
    Logger.warn("Prompt failed.")
    return
  end

  local result = req.cmd ~= nil and req or PARSER.parse(requests, req.start_line)
  local start = vim.loop.hrtime()

  vim.fn.jobstart(result.cmd, {
    on_stderr = function(_, datalist)
      if datalist then
        errors = errors or {}
        vim.list_extend(errors, datalist)
      end
    end,
    on_stdout = function(_, lines, _)
      local contents = table.concat(lines, "\n")
      if contents == "" then
        return
      end
      stats = vim.fn.json_decode(contents)
    end,
    on_exit = function(_, code)
      local success = code == 0
      if success then
        local body = Fs.read_file(GLOBALS.BODY_FILE)
        if stats then
          Fs.write_file(GLOBALS.STATS_FILE, vim.fn.json_encode(stats), false)
        end
        if verbose_mode and errors then
          Fs.write_file(GLOBALS.ERRORS_FILE, table.concat(errors, "\n"), false)
        end
        for _, metadata in ipairs(result.metadata) do
          if metadata then
            if metadata.name == "name" then
              INT_PROCESSING.set_env_for_named_request(metadata.value, body)
            elseif metadata.name == "env-json-key" then
              INT_PROCESSING.env_json_key(metadata.value, body)
            elseif metadata.name == "env-header-key" then
              INT_PROCESSING.env_header_key(metadata.value)
            elseif metadata.name == "stdin-cmd" then
              EXT_PROCESSING.stdin_cmd(metadata.value, body)
            elseif metadata.name == "env-stdin-cmd" then
              EXT_PROCESSING.env_stdin_cmd(metadata.value, body)
            end
          end
        end
        INT_PROCESSING.redirect_response_body_to_file(result.redirect_response_body_to_files)

        local has_post_request_scripts = #result.scripts.post_request.inline > 0
          or #result.scripts.pre_request.files > 0
        if has_post_request_scripts then
          PARSER.scripts.javascript.run("post_request", result.scripts.post_request)
        end
        Api.trigger("after_next_request")
        Api.trigger("after_request")
      end
      Fs.delete_request_scripts_files()
      if callback then
        callback(success, start)
      end
    end,
  })
end

---Runs the parser and returns the result
M.run_parser_all = function(requests, variables, callback)
  local verbose_mode = CONFIG.get().default_view == "verbose"

  for _, req in ipairs(requests) do
    offload_task(function()
      if process_prompt_vars(req) == false then
        if req.show_icon_line_number then
          INLAY:show_error(req.show_icon_line_number)
        end
        Logger.warn("Prompt failed. Skipping this and all following requests.")
        return false
      end

      local result = PARSER.parse(requests, req.start_line, variables)
      if not result then
        return
      end

      local icon_linenr = result.show_icon_line_number
      if icon_linenr then
        INLAY:show_loading(icon_linenr)
      end
      local start = vim.loop.hrtime()
      local success = false
      local errors

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
        local body = Fs.read_file(GLOBALS.BODY_FILE)
        if stats then
          Fs.write_file(GLOBALS.STATS_FILE, vim.fn.json_encode(stats), false)
        end
        if verbose_mode and errors then
          Fs.write_file(GLOBALS.ERRORS_FILE, errors, false)
        end
        for _, metadata in ipairs(result.metadata) do
          if metadata then
            if metadata.name == "name" then
              INT_PROCESSING.set_env_for_named_request(metadata.value, body)
            elseif metadata.name == "env-json-key" then
              INT_PROCESSING.env_json_key(metadata.value, body)
            elseif metadata.name == "env-header-key" then
              INT_PROCESSING.env_header_key(metadata.value)
            elseif metadata.name == "stdin-cmd" then
              EXT_PROCESSING.stdin_cmd(metadata.value, body)
            elseif metadata.name == "env-stdin-cmd" then
              EXT_PROCESSING.env_stdin_cmd(metadata.value, body)
            end
          end
        end
        INT_PROCESSING.redirect_response_body_to_file(result.redirect_response_body_to_files)
        PARSER.scripts.javascript.run("post_request", result.scripts.post_request)
        Api.trigger("after_next_request")
        Api.trigger("after_request")
      end
      Fs.delete_request_scripts_files()
      if callback then
        callback(success, start, icon_linenr)
      end
      return true
    end)
  end
end

return M
