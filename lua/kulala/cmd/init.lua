local GLOBALS = require("kulala.globals")
local FS = require("kulala.utils.fs")
local EXT_PROCESSING = require("kulala.external_processing")
local INT_PROCESSING = require("kulala.internal_processing")

local M = {}

---Runs the command and returns the result
---@param cmd table command to run
---@param callback function callback function
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
M.run_parser = function(result, callback)
  vim.fn.jobstart(result.cmd, {
    on_stderr = function(_, datalist)
      if callback then
        if #datalist > 0 and #datalist[1] > 0 then
          vim.notify(vim.inspect(datalist), vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, code)
      local success = code == 0
      if success then
        local body = FS.read_file(GLOBALS.BODY_FILE)
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
      end
      if callback then
        callback(success)
      end
    end,
  })
end

return M
