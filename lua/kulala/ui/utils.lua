local DB = require("kulala.db")

---@param bufnr number
---@param ns number
---@param start_pos table|number
---@param end_pos table|number
---@param hl_group string
local function highlight_range(bufnr, ns, start_pos, end_pos, hl_group)
  bufnr = bufnr == 0 and DB.get_current_buffer() or bufnr
  ns = ns == 0 and vim.api.nvim_create_namespace("kulala_highlight") or ns

  start_pos = type(start_pos) == "table" and start_pos or { start_pos, 0 }
  end_pos = type(end_pos) == "table" and end_pos or { end_pos, -1 }

  vim.highlight.range(bufnr, ns, hl_group, start_pos, end_pos, { regtype = "v", priority = 1000, inclusive = true })
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
    flash_highlight(DB.get_current_buffer(), ns, 100, request.start_line, request.end_line)
  end
end

local Ptable = {
  header = {},
  widths = {},

  new = function(self, o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
  end,

  get_row = function(self, row, indent)
    indent = indent or 0
    return vim
      .iter(row)
      :enumerate()
      :map(function(i, col)
        return self.sep(indent) .. col .. self.sep(math.max(0, self.widths[i] - #tostring(col) - indent))
      end)
      :join("")
  end,

  get_headers = function(self)
    return self:get_row(self.header)
  end,

  sep = function(n)
    return string.rep(" ", n)
  end,
}

return {
  highlight_range = highlight_range,
  highlight_request = highlight_request,
  Ptable = Ptable,
}
