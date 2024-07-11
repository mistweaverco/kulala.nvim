local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local FORMATTER = require("kulala.formatter")
local CLIENT_PIPE = require("kulala.client_pipe")
local FS = require("kulala.utils.fs")

local M = {}

-- runs the cmd and maybe formats the result
M.run = function(result, callback)
  vim.fn.jobstart(result.cmd, {
    on_stdout = function(_, datalist)
      -- do nothing
    end,
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
        if result.ft ~= "text" and not result.client_pipe then
          FS.write_file(GLOBALS.BODY_FILE, FORMATTER.format(result.ft, body))
        end
        if result.client_pipe then
          body = CLIENT_PIPE.pipe(result.client_pipe, body)
        end
      end
      if callback then
        callback(success)
      end
    end,
  })
end

return M
