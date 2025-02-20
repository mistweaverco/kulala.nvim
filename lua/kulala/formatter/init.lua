local Logger = require("kulala.logger")

local M = {}

M.format = function(formatter, contents)
  if type(formatter) == "function" then
    return formatter(contents)
  elseif type(formatter) == "table" then
    local cmd = formatter
    local ret = vim.system(cmd, { stdin = contents, text = true }):wait()

    if ret.code == 0 then
      return ret.stdout
    else
      Logger.warn(("Error running external formatter: %s"):format(ret.stderr))
    end
  end

  return contents
end

return M
