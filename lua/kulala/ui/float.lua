local M = {}

---@enum FloatPosition
local FLOAT_POSITION = {
  Center = "center",
  Cursor = "cursor",
}

---@class FloatOpts
---@field contents string[] @Contents of the buffer
---@field ft string? @Filetype of the buffer
---@field focusable boolean? @Whether the window is focusable
---@field position FloatPosition @Position of the floating window

---Creates a floating window with the contents passed via opts
---@param opts FloatOpts
---@return integer, integer @Window and buffer IDs
M.create = function(opts)
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

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
    relative = win_config_relative,
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = opts.focusable or false,
  }

  -- Create the floating window with the buffer
  local win = vim.api.nvim_open_win(buf, opts.focusable or false, win_config)

  -- Return the window and buffer IDs
  return win, buf
end

return M
