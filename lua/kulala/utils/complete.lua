local Parser = require("kulala.parser.document")

local M = {}

-- Determine if the current line is a request line (method + URL)
local function is_run(line)
  return line:match("^run")
end

local function complete_requests(_)
  local _, _, requests = Parser.get_document()

  return vim
    .iter(requests)
    :map(function(request)
      return {
        word = "#" .. request.name,
        menu = request.file,
      }
    end)
    :totable()
end

function M.complete(findstart, base)
  local line = vim.api.nvim_get_current_line()

  -- First call - find the start position of the word to complete
  if findstart == 1 then
    if is_run(line) then return line:find("^run") - 2 end
    return -1
  else
    -- Second call - return completion items
    if is_run(line) then return complete_requests(base) end
    return {}
  end
end

return M
