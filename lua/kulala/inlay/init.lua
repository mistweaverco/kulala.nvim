local NS = vim.api.nvim_create_namespace("kulala_inlay_hints")
local CONFIG = require("kulala.config")

local M = {}

M.get_current_line_number = function()
  local linenr = vim.api.nvim_win_get_cursor(0)[1]
  return linenr
end

M.clear = function()
  vim.api.nvim_buf_clear_namespace(0, NS, 0, -1)
end

M.clear_if_marked = function(bufnr, linenr)
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, NS, { linenr - 1, 0 }, { linenr - 1, -1 }, {})
  if #extmarks > 0 then
    local extmark_id = extmarks[1][1]
    vim.api.nvim_buf_del_extmark(bufnr, NS, extmark_id)
  end
end

M.show_loading = function(self, linenr)
  M.show(CONFIG.get().icons.inlay.loading, linenr)
end

M.show_error = function(self, linenr)
  M.show(CONFIG.get().icons.inlay.error, linenr)
end

M.show_done = function(self, linenr, elapsed_time)
  local icon = ""
  if string.len(CONFIG.get().icons.inlay.done) > 0 then
    icon = CONFIG.get().icons.inlay.done .. " "
  end
  M.show(icon .. elapsed_time, linenr)
end

M.show = function(t, linenr)
  local bufnr = vim.api.nvim_get_current_buf()
  M.clear_if_marked(bufnr, linenr)
  vim.api.nvim_buf_set_extmark(bufnr, NS, linenr - 1, 0, {
    virt_text = { { t } },
  })
end

return M
