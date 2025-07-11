local Logger = require("kulala.logger")

local M = {}

M.format = function(formatter, contents, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    verbose = true,
  })

  if type(formatter) == "function" then
    return formatter(contents)
  elseif type(formatter) == "table" then
    local cmd = formatter

    local status, result = pcall(function()
      return vim.system(cmd, { stdin = contents, text = true }):wait()
    end)

    if not status or result.code ~= 0 then
      _ = opts.verbose
        and Logger.warn(("Error running external formatter: %s"):format(not status and result or result.stderr))
      return contents
    end

    return result.stdout
  end

  return contents
end

return M
