local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local NS = vim.api.nvim_create_namespace("kulala_inlay_hints")

local M = {}

M.get_current_line_number = function()
  local win_id = vim.fn.bufwinid(DB.get_current_buffer())
  return vim.api.nvim_win_get_cursor(win_id)[1]
end

M.clear = function()
  vim.api.nvim_buf_clear_namespace(DB.get_current_buffer(), NS, 0, -1)
end

M.clear_if_marked = function(bufnr, linenr)
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, NS, { linenr - 1, 0 }, { linenr - 1, -1 }, {})
  if #extmarks > 0 then
    local extmark_id = extmarks[1][1]
    vim.api.nvim_buf_del_extmark(bufnr, NS, extmark_id)
  end
end

M.show_loading = function(_, linenr)
  _ = linenr and M.show(CONFIG.get().icons.inlay.loading, linenr)
end

M.show_error = function(_, linenr)
  _ = linenr and M.show(CONFIG.get().icons.inlay.error, linenr)
end

M.show_done = function(_, linenr, elapsed_time)
  local icon = ""
  if string.len(CONFIG.get().icons.inlay.done) > 0 then
    icon = CONFIG.get().icons.inlay.done .. " "
  end
  _ = linenr and M.show(icon .. elapsed_time, linenr)
end

local line_ofset = {
  ["on_request"] = -1,
  ["above_request"] = -2,
  ["below_request"] = 0,
}

M.show = function(t, linenr)
  local show_icons = CONFIG.get().show_icons
  if not show_icons then
    return
  end

  local bufnr = DB.get_current_buffer()
  linenr = linenr + (line_ofset[show_icons] or 0)

  M.clear_if_marked(bufnr, linenr)
  vim.api.nvim_buf_set_extmark(bufnr, NS, linenr - 1, 0, {
    virt_text = { { t } },
  })
end

return M
