local NS = vim.api.nvim_create_namespace('jest.nvim')
local CONFIG = require("kulala.config")

local M = {}

local function get_current_line_number()
  local linenr = vim.api.nvim_win_get_cursor(0)[1]
  return linenr
end

M.clear = function()
  vim.api.nvim_buf_clear_namespace(0, NS, 0, -1)
end

M.show_loading = function()
  M.show(CONFIG.get_config().icons.inlay.loading)
end

M.show_done = function(self, elapsed_time)
  M.show(CONFIG.get_config().icons.inlay.done .. elapsed_time)
end


M.show = function(t)
  M.clear()
  local linenr = get_current_line_number()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_extmark(bufnr, NS, linenr - 1, 0, {
    virt_text = { { t } }
  })
end

return M
