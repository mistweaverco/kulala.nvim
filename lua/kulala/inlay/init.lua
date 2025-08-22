local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local NS = vim.api.nvim_create_namespace("kulala_inlay_hints")

local M = {}

---Get the current line number, 1-indexed
M.get_current_line_number = function()
  local win_id = vim.fn.bufwinid(DB.get_current_buffer())
  return vim.api.nvim_win_get_cursor(win_id)[1]
end

M.clear = function(name)
  local buf = DB.get_current_buffer()

  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  if not name then return vim.fn.sign_unplace("kulala", { name = name, buffer = buf }) end

  local signs = name and vim.fn.sign_getplaced(buf, { group = "kulala" }) or {}
  vim.iter(signs[1].signs or {}):each(function(s)
    _ = s.name == name and vim.fn.sign_unplace("kulala", { id = s.id, buffer = buf })
  end)
end

M.clear_if_marked = function(bufnr, linenr)
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, NS, { linenr - 1, 0 }, { linenr - 1, -1 }, {})

  if #extmarks > 0 then
    local extmark_id = extmarks[1][1]
    vim.api.nvim_buf_del_extmark(bufnr, NS, extmark_id)
  end

  vim.fn.sign_unplace("kulala", { buffer = DB.get_current_buffer(), id = linenr })
end

local function set_signcolumn()
  local buf = DB.get_current_buffer()
  local win = vim.fn.win_findbuf(buf)[1]
  if win == -1 then return end
end

local line_offset = {
  ["signcolumn"] = -1,
  ["on_request"] = -1,
  ["above_request"] = -2,
  ["below_request"] = 0,
}

M.show = function(buf, event, linenr, text)
  local config = CONFIG.get()
  local show_icons = config.show_icons

  if not (config.show_icons and linenr) then return end

  local icon = config.icons.inlay[event] or ""
  linenr = math.max(linenr + (line_offset[show_icons] or 0), 1)

  M.clear_if_marked(buf, linenr)

  local virt_text = { { text or "", config.icons.textHighlight } }
  local color = event == "error" and config.icons.errorHighlight
    or (event == "done" and config.icons.doneHighlight or config.icons.loadingHighlight)

  if show_icons == "signcolumn" then
    set_signcolumn()
    vim.fn.sign_place(linenr, "kulala", "kulala." .. event, buf, { lnum = linenr })
  else
    table.insert(virt_text, 1, { icon .. " ", color })
  end

  vim.api.nvim_buf_set_extmark(buf, NS, linenr - 1, 0, {
    hl_mode = "combine",
    virt_text = virt_text,
  })
end

return M
