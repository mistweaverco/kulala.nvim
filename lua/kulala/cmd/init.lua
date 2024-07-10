local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local FORMATTER = require("kulala.formatter")
local FS = require("kulala.utils.fs")

local M = {}

-- runs the cmd and maybe formats the result
M.run = function(result, callback)
  vim.fn.jobstart(result.cmd, {
    on_stdout = function(_, datalist)
      if result.ft then
        local body = FS.read_file(GLOBALS.BODY_FILE)
        FS.write_file(GLOBALS.BODY_FILE, FORMATTER.format(result.ft, body))
      end
    end,
    on_stderr = function(_, datalist)
      if callback then
        if #datalist > 0 and #datalist[1] > 0 then
          vim.notify(vim.inspect(datalist), vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, code)
      if callback then
        callback(code == 0)
      end
    end,
  })
end

return M
