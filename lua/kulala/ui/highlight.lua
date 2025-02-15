local DB = require("kulala.db")

---@class Position
---@field row number
---@field col number

---@param bufnr number
---@param ns number
---@param start_pos Position
---@param end_pos Position
---@param hl_group string
local function highlight_range(bufnr, ns, start_pos, end_pos, hl_group)
  bufnr = bufnr == 0 and DB.get_current_buffer() or bufnr
  ns = ns == 0 and vim.api.nvim_create_namespace("kulala_highlight") or ns

  -- don't highlight over the last line
  if end_pos.col == 0 then
    end_pos.row = end_pos.row - 1
    end_pos.col = -1
  end

  vim.highlight.range(
    bufnr,
    ns,
    hl_group,
    { start_pos.row, start_pos.col },
    { end_pos.row, end_pos.col },
    { regtype = "v" }
  )
end

local function flash_highlight(bufnr, ns, timeout, start_pos, end_pos)
  highlight_range(bufnr, ns, start_pos, end_pos, "IncSearch")

  -- clear buffer highlights after timeout
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      vim.cmd("redraw")
    end
  end, timeout)
end

---@param request DocumentRequest
local function highlight_request(request)
  local ns = vim.api.nvim_create_namespace("kulala_requests_flash")

  if request.start_line and request.end_line then
    flash_highlight(
      DB.get_current_buffer(),
      ns,
      100,
      { row = request.start_line, col = 0 },
      { row = request.end_line, col = 0 }
    )
  end
end

return {
  highlight_range = highlight_range,
  highlight_request = highlight_request,
}
