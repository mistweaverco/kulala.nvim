local Table = require("kulala.utils.table")
local Utils = require("kulala.ui.utils")

local M = {}

---@class FloatOpts
---@field buf integer? Relative buffer id
---@field name string? @Name of the buffer
---
---@field win integer? Relative window id
---@field title string? @Title of the floating window
---
---@field relative string? Relative position
---@field anchor string? Anchor position
---@field zindex integer? z-index of the floating window
---
---@field focusable boolean? Whether the window is focusable
---@field mouse boolean? Whether the floating window is mouse enabled
---
---@field width integer? Width
---@field height integer? Height
---@field auto_size boolean? Autosize to the content
---
---@field row integer? Row
---@field col integer? Column
---@field row_offset integer? Row offset from the bottom
---@field col_offset integer? Col offset from the right
---
---@field style string? Style
---@field border string? Border
---
---@field hl_group string? Highlight group of the floating window
---@field ft string? Filetype of the buffer
---
---@field close_keymaps string[]? List of keymaps to close the floating window
---@field auto_close boolean? Whether the floating window should close automatically
---
---@field bo table? Buffer options
---@field wo table? Window options

---@param opts FloatOpts
local function float_defaults(opts)
  local win = opts.win or 0

  local height = math.max(1, vim.api.nvim_win_get_height(win))
  local width = math.max(1, vim.api.nvim_win_get_width(win))

  local row = opts.relative == "cursor" and 1 or height - (opts.row_offset or 0)
  local col = opts.relative == "cursor" and 1 or width - (opts.col_offset or 0)

  local win_opts = Table.remove_keys(vim.deepcopy(opts), {
    "buf",
    "name",
    "auto_size",
    "row_offset",
    "col_offset",
    "hl_group",
    "ft",
    "close_keymaps",
    "auto_close",
    "bo",
    "wo",
  })

  return vim.tbl_extend("keep", win_opts, {
    relative = "win",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "none",
    focusable = false,
    mouse = vim.fn.has("nvim-0.11") == 1 and true or nil,
    zindex = 100,
  })
end

local function set_close_keymaps(buf, win, keymaps)
  vim.iter(keymaps or {}):each(function(key)
    vim.keymap.set("n", key, function()
      vim.api.nvim_win_close(win, true)
      vim.api.nvim_buf_delete(buf, { force = true })
    end, { buffer = buf, noremap = true, silent = true })
  end)
end

local function set_autoclose(buf, win)
  if not buf or not win then return end

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buf,
    once = true,
    callback = function()
      _ = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_close(win, true)
    end,
  })
end

local function set_autosize(text, opts)
  local width = 0

  vim.iter(text):each(function(line)
    width = math.max(width, #line)
  end)

  opts.width = math.min(width, vim.o.columns)
  opts.height = math.min(#text, vim.o.lines)

  return opts
end

local function set_buffer_options(buf, bo)
  vim.iter(bo):each(function(opt, value)
    vim.api.nvim_set_option_value(opt, value, { buf = buf })
  end)
end

local function set_window_options(win, wo)
  vim.iter(wo):each(function(opt, value)
    vim.api.nvim_set_option_value(opt, value, { win = win })
  end)
end

---@param text string|string[] Text to display
---@param opts FloatOpts Options for the floating window
M.create = function(text, opts)
  text = text or { "Text" }
  text = type(text) == "table" and text or { text }

  opts = opts or {}
  opts.name = opts.name or "kulala://float"
  opts.focusable = opts.focusable or false

  local buf = vim.api.nvim_create_buf(false, true)

  local existing = vim.fn.bufnr(opts.name)
  _ = existing > -1 and vim.api.nvim_buf_delete(existing, { force = true })
  _ = vim.fn.bufnr(opts.name) == -1 and vim.api.nvim_buf_set_name(buf, opts.name)

  vim.api.nvim_buf_set_lines(buf, 0, -1, true, text)

  if opts.ft then vim.bo[buf].filetype = opts.ft end
  if opts.hl_group then Utils.highlight_range(buf, 0, 0, 0, opts.hl_group) end

  _ = opts.auto_size and set_autosize(text, opts)

  local win = vim.api.nvim_open_win(buf, opts.focusable, float_defaults(opts))

  _ = opts.auto_close and set_autoclose(opts.buf, win)
  _ = opts.close_keymaps and set_close_keymaps(buf, win, opts.close_keymaps)
  _ = opts.bo and set_buffer_options(buf, opts.bo)
  _ = opts.wo and set_window_options(win, opts.wo)

  return {
    buf = buf,
    win = win,
    close = function()
      _ = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_close(win, true)
      _ = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_delete(buf, { force = true })
    end,
  }
end

---@param text string|string[] Text to display
---@param opts FloatOpts Options for the floating window
M.create_window_footer = function(text, opts)
  local float_opts = float_defaults(opts)
  text = (" "):rep(float_opts.width - #text) .. text

  opts.relative = "win"
  opts.hl_group = "Special"
  opts.height = 1
  opts.anchor = "NE"

  return M.create(text, opts)
end

---@param text string|string[] Text to display
---@param opts FloatOpts|nil Options for the floating window
M.create_progress_float = function(text, opts)
  text = text or ""
  opts = opts or {}
  opts.hl_group = opts.hl_group or "Special"

  local timer = vim.uv.new_timer()
  local icons, i = { "", "󰀚", "" }, 0

  local icon = vim.iter(function()
    i = i + 1
    return icons[i % #icons + 1]
  end)

  local float = M.create(text, {
    title = "Kulala",
    title_pos = "center",
    name = "kulala://progress",
    relative = "editor",
    anchor = "NE",
    row = 1,
    col_offset = 1,
    border = "rounded",
    width = #text + 6,
    height = 1,
  })

  vim.api.nvim_set_option_value("winhl", "FloatBorder:Special", { win = float.win })

  timer:start(0, 500, function()
    local msg = " " .. icon:next() .. "  " .. text .. "  "
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(float.buf) then return timer:close() end

      vim.api.nvim_buf_set_lines(float.buf, 0, -1, true, { msg })
      _ = opts.hl_group and Utils.highlight_range(float.buf, 0, 0, 0, opts.hl_group)
    end)
  end)

  float.hide = function()
    pcall(function()
      timer:close()
    end)
    vim.schedule(float.close)
  end

  return float
end

return M
