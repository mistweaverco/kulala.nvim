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
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
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

return {
  highlight_range = highlight_range,
}
