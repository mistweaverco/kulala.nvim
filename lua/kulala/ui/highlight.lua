local DB = require("kulala.db")

---@class Position
---@field row number
---@field col number

---@param bufnr number
---@param start_pos Position
---@param end_pos Position
---@param ns number
---@param timeout number
---@param callback function|nil
local function highlight_range(bufnr, start_pos, end_pos, ns, timeout, callback)
  bufnr = bufnr == 0 and DB.get_current_buffer() or bufnr

  local higroup = "IncSearch"
  -- don't highlight over the last line
  if end_pos.col == 0 then
    end_pos.row = end_pos.row - 1
    end_pos.col = -1
  end

  vim.highlight.range(
    bufnr,
    ns,
    higroup,
    { start_pos.row, start_pos.col },
    { end_pos.row, end_pos.col },
    { regtype = "v" }
  )

  -- clear buffer highlights after timeout
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      vim.cmd("redraw")

      if callback then
        callback()
      end
    end
  end, timeout)
end

---@param request DocumentRequest
local function highlight_request(request, callback)
  local ns = vim.api.nvim_create_namespace("kulala_requests_flash")

  if not request.start_line or not request.end_line then
    return
  end

  highlight_range(0, { row = request.start_line, col = 0 }, { row = request.end_line, col = 0 }, ns, 100, callback)
end

return {
  highlight_range = highlight_range,
  highlight_request = highlight_request,
}
