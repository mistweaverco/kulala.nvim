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

return M
