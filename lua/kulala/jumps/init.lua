local PARSER = require("kulala.parser.document")

local M = {}

-- Function to move to the next "request" node
M.jump_next = function()
  local _, reqs = PARSER.get_document()
  local next = PARSER.get_next_request(reqs)
  if next then
    vim.api.nvim_win_set_cursor(0, { next.start_line + 1, 0 })
  end
end

-- Function to move to the previous "request" node
M.jump_prev = function()
  local _, reqs = PARSER.get_document()
  local prev = PARSER.get_previous_request(reqs)
  if prev then
    vim.api.nvim_win_set_cursor(0, { prev.start_line + 1, 0 })
  end
end

return M
