local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local NS = vim.api.nvim_create_namespace("kulala_inlay_hints")

local M = {}

---Get the current line number, 1-indexed
M.get_current_line_number = function()
  local win_id = vim.fn.bufwinid(DB.get_current_buffer())
  return vim.api.nvim_win_get_cursor(win_id)[1]
end

M.clear = function()
  local buf = DB.get_current_buffer()

  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  vim.fn.sign_unplace("kulala", { buffer = buf })
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

  local scl = (vim.api.nvim_get_option_value("signcolumn", { win = win }) or "")
  scl = tonumber(scl:sub(#scl)) or 0

  vim.api.nvim_set_option_value("signcolumn", "yes:" .. math.max(2, scl), { win = win })
end

local line_offset = {
  ["signcolumn"] = -1,
  ["on_request"] = -1,
  ["above_request"] = -2,
  ["below_request"] = 0,
}

M.show = function(event, linenr, text)
  local config = CONFIG.get()
  local bufnr = DB.get_current_buffer()
  local show_icons = config.show_icons

  if not (config.show_icons and linenr) then return end

  local icon = config.icons.inlay[event] or ""
  linenr = math.max(linenr + (line_offset[show_icons] or 0), 1)
  text = text or ""

  M.clear_if_marked(bufnr, linenr)

  if show_icons == "signcolumn" then
    set_signcolumn()
    vim.fn.sign_place(linenr, "kulala", "kulala." .. event, bufnr, { lnum = linenr })
    vim.fn.sign_place(linenr + 10000, "kulala", "kulala.space", bufnr, { lnum = linenr })
  else
    text = icon .. " " .. text
  end

  vim.api.nvim_buf_set_extmark(bufnr, NS, linenr - 1, 0, { virt_text = { { text, config.icons.textHighlight } } })
end

return M
