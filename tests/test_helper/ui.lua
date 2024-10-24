local api = vim.api

local UITestHelper = {}

UITestHelper.delete_all_bufs = function()
  -- Get a list of all buffer numbers
  local buffers = vim.api.nvim_list_bufs()

  -- Iterate over each buffer and delete it
  for _, buf in ipairs(buffers) do
    -- Check if the buffer is valid and loaded
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end

---@param lines? string[]
---@param bufname? string
---@return integer bufnr
UITestHelper.create_buf = function(lines, bufname)
  lines = lines or {}
  local bufnr = vim.api.nvim_create_buf(true, true)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  api.nvim_set_current_buf(bufnr)
  api.nvim_win_set_cursor(0, { 1, 1 })

  if bufname then
    vim.api.nvim_buf_set_name(bufnr, bufname)
  end

  return bufnr
end

---@param bufnr integer
---@return string[] lines
UITestHelper.get_buf_lines = function(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

---@return integer[] bufnr list
UITestHelper.list_loaded_bufs = function()
  local bufnr_list = vim.api.nvim_list_bufs()

  local loaded_bufs = {}
  for _, bufnr in ipairs(bufnr_list) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      loaded_bufs[#loaded_bufs + 1] = bufnr
    end
  end

  return loaded_bufs
end

return UITestHelper
