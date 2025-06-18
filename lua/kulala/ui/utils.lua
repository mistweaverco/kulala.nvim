local DB = require("kulala.db")

local function kulala_highlight()
  return vim.api.nvim_create_namespace("kulala_highlight")
end

local function clear_highlights(bufnr, ns)
  bufnr = bufnr and bufnr or DB.get_current_buffer()
  ns = ns and ns or kulala_highlight()

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

---@param bufnr number
---@param ns number
---@param start_pos table|number
---@param end_pos table|number
---@param hl_group string
local function highlight_range(bufnr, ns, start_pos, end_pos, hl_group, priority)
  bufnr = bufnr == 0 and DB.get_current_buffer() or bufnr
  ns = ns ~= 0 and ns or kulala_highlight()

  start_pos = type(start_pos) == "table" and start_pos or { start_pos, 0 }
  end_pos = type(end_pos) == "table" and end_pos or { end_pos, -1 }

  local highlight = vim.fn.has("nvim-0.11") == 1 and vim.hl.range or vim.highlight.range
  highlight(bufnr, ns, hl_group, start_pos, end_pos, { priority = priority or 1 })
end

local function highlight_column(bufnr, ns, start_pos, end_pos, hl_group, priority)
  for line = start_pos[1], end_pos[1] do
    highlight_range(bufnr, ns, { line, start_pos[2] }, { line, end_pos[2] }, hl_group, priority)
  end
end

-- Higlights buffer according to template: (1-indexed)
-- { [1] = { config.successHighlight, 40, 60, config.errorHighlight, 60, 80, ... }, [2] = .. }
-- where each entry corresponds to a line number
-- and each higlight is a triplet of hl_group, col_start, col_end
local function highlight_buffer(bufnr, ns, highlights, priority)
  local hl, col_s, col_e
  local width = vim.api.nvim_win_get_width(vim.fn.bufwinid(bufnr))

  for lnum, highlight in pairs(highlights) do
    highlight = type(highlight) == "table" and highlight or { highlight }

    for i = 1, #highlight, 3 do
      hl = highlight[i]
      col_s = highlight[i + 1] or 0
      col_e = highlight[i + 2] or width

      highlight_range(bufnr, ns, { lnum - 1, col_s }, { lnum - 1, col_e }, hl, priority)
    end
  end
end

local function set_virtual_text(buf, ns, virtual_text, line, col, opts)
  opts = opts or {}
  buf = buf == 0 and DB.get_current_buffer() or buf
  ns = ns == 0 and vim.api.nvim_create_namespace("kulala_virtual_text") or ns

  opts = vim.tbl_extend("keep", opts, {
    hl_group = "Comment",
    virt_text = { { virtual_text, opts.hl_group or "Comment" } },
    virt_text_pos = "right_align",
    invalidate = false,
  })
  return vim.api.nvim_buf_set_extmark(buf, ns, line, col, opts)
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
    flash_highlight(DB.get_current_buffer(), ns, 100, request.start_line, request.end_line - 1)
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
        col = tostring(col):sub(1, self.widths[i] - 1) -- truncate if too long
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

---Pretty print time in milliseconds
local function pretty_ms(ms)
  ms = ms == "" and 0 or ms
  return ("%.2f ms"):format(ms / 1e6)
end

return {
  kulala_highlight = kulala_highlight,
  clear_highlights = clear_highlights,
  highlight_range = highlight_range,
  highlight_column = highlight_column,
  highlight_buffer = highlight_buffer,
  highlight_request = highlight_request,
  set_virtual_text = set_virtual_text,
  Ptable = Ptable,
  pretty_ms = pretty_ms,
}
