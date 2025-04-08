local Utils = require("kulala.ui.utils")
local M = {}

---@enum FloatPosition
local FLOAT_POSITION = {
  Center = "center",
  Cursor = "cursor",
}

---@class FloatOpts
---@field title string? @Title of the floating window
---@field buf_name string? @Name of the buffer
---@field contents string[] @Contents of the buffer
---@field ft string? @Filetype of the buffer
---@field focusable boolean? @Whether the window is focusable
---@field position FloatPosition @Position of the floating window
---@field width integer? @Width of the floating window
---@field height integer? @Height of the floating window
---@field zindex integer? @Z-index of the floating window
---@field close_keymaps string[]? @List of keymaps to close the floating window

---Creates a floating window with the contents passed via opts
---@param opts FloatOpts
---@return integer, integer @Window and buffer IDs
M.create = function(opts)
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  _ = opts.buf_name and vim.api.nvim_buf_set_name(buf, opts.buf_name)

  local win_config_relative = "editor"

  -- Set the content of the buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.contents)

  if opts.ft then vim.bo[buf].filetype = opts.ft end

  -- Get the total dimensions of the editor
  local total_width = vim.o.columns
  local total_height = vim.o.lines

  -- Calculate the content dimensions
  local content_width = 0
  for _, line in ipairs(opts.contents) do
    if #line > content_width then content_width = #line end
  end
  local content_height = #opts.contents

  -- Ensure the window doesn't exceed the total size
  local win_width = math.min(content_width, math.floor(total_width))
  local win_height = math.min(content_height, math.floor(total_height))

  local row = 0
  local col = 0

  if opts.position == FLOAT_POSITION.Center then
    -- Ensure the window doesn't exceed 80% of the total size
    win_width = math.min(content_width, math.floor(total_width * 0.8))
    win_height = math.min(content_height, math.floor(total_height * 0.8))
    -- Calculate the window position to center it
    row = math.floor((total_height - win_height) / 2)
    col = math.floor((total_width - win_width) / 2)
  elseif opts.position == FLOAT_POSITION.Cursor then
    -- Adjust the position relative to the cursor
    win_config_relative = "cursor"
    row = 1 -- Move the float one line below the cursor
    col = 1 -- Move the float one column to the right of the cursor
  end

  -- Define the floating window configuration
  local win_config = {
    title = opts.title or "",
    relative = win_config_relative,
    width = opts.width or win_width,
    height = opts.height or win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = opts.focusable or false,
    zindex = opts.zindex or 100,
  }

  -- Create the floating window with the buffer
  local win = vim.api.nvim_open_win(buf, opts.focusable or false, win_config)

  -- Set the keymaps to close the floating window
  vim.iter(opts.close_keymaps or {}):each(function(key)
    vim.keymap.set("n", key, function()
      vim.api.nvim_win_close(win, true)
      vim.api.nvim_buf_delete(buf, { force = true })
    end, { buffer = buf, noremap = true, silent = true })
  end)

  -- Return the window and buffer IDs
  return win, buf
end

M.create_window_footer = function(buf_id, win_id, text, opts)
  buf_id = buf_id or 0
  win_id = win_id or 0
  opts = opts or {}

  local win_height = vim.api.nvim_win_get_height(win_id)
  local win_width = vim.api.nvim_win_get_width(win_id)

  local buf = vim.api.nvim_create_buf(false, true)
  local buf_name = opts.buf_name or "kulala://footer"

  local existing = vim.fn.bufnr(buf_name)
  _ = existing > -1 and vim.api.nvim_buf_delete(existing, { force = true })
  _ = vim.fn.bufnr(buf_name) == -1 and vim.api.nvim_buf_set_name(buf, buf_name)

  text = (" "):rep(win_width - #text) .. text
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, { text })

  if opts.hl_group then Utils.highlight_range(buf, 0, 0, 0, opts.hl_group) end

  local float_win = vim.api.nvim_open_win(buf, false, {
    relative = "win",
    win = win_id,
    width = win_width,
    height = 1,
    row = win_height - (opts.row_offset or 2),
    col = 0,
    style = "minimal",
    focusable = false,
    zindex = 100,
    border = opts.border or "none",
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buf_id,
    once = true,
    callback = function()
      _ = vim.api.nvim_win_is_valid(float_win) and vim.api.nvim_win_close(float_win, true)
    end,
  })

  return float_win, buf
end

return M
