local CONFIG = require("kulala.config")
local Float = require("kulala.ui.float")
local KEYMAPS = require("kulala.config.keymaps")
local WEBSOCKET = require("kulala.cmd.websocket")

local M = {}

local OVERLAY_NAME = "kulala://ws_message"

---@type { buf: number, win: number, parent_win: number }|nil
local state = nil
local opening = false

local function is_ws_method(method)
  method = (method or ""):upper()
  return method == "WS" or method == "WSS" or method == "WEBSOCKET"
end

local function kulala_keymap_keys(name)
  local maps = KEYMAPS.get_kulala_keymaps() or {}
  local map = maps[name]
  if not map or not map[1] then return {} end
  if type(map[1]) == "table" then return map[1] end
  return { map[1] }
end

local function kulala_keymap_modes(name)
  local maps = KEYMAPS.get_kulala_keymaps() or {}
  local map = maps[name]
  if not map or not map.mode then return { "n", "i", "v" } end
  if type(map.mode) == "table" then return map.mode end
  return { map.mode }
end

local function overlay_text()
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  return vim.trim(table.concat(lines, "\n"))
end

function M.is_open()
  return state ~= nil and vim.api.nvim_buf_is_valid(state.buf) and vim.api.nvim_win_is_valid(state.win)
end

function M.close()
  if not state then return end
  local parent = state.parent_win
  if vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_close(state.win, true) end
  if vim.api.nvim_buf_is_valid(state.buf) then vim.api.nvim_buf_delete(state.buf, { force = true }) end
  state = nil
  if parent and vim.api.nvim_win_is_valid(parent) then vim.api.nvim_set_current_win(parent) end
end

function M.send_and_close()
  if opening or not M.is_open() then return end
  local text = overlay_text()
  M.close()
  if text ~= "" then WEBSOCKET.send(text) end
end

---@return boolean
function M.can_open_from_body()
  if not WEBSOCKET.is_active() then return false end
  local UI = require("kulala.ui")
  local response = UI.get_current_response()
  if not is_ws_method(response.method) then return false end
  if CONFIG.get().default_view ~= "body" then return false end
  local buf = UI.get_kulala_buffer()
  return buf and vim.fn.bufwinid(buf) > 0
end

local function bind_overlay_keymaps(buf)
  local send_keys = kulala_keymap_keys("Send WS message")
  local send_modes = kulala_keymap_modes("Send WS message")

  local map_opts = { buffer = buf, desc = "Send WebSocket message", nowait = true, noremap = true, silent = true }
  for _, key in ipairs(send_keys) do
    for _, mode in ipairs(send_modes) do
      vim.keymap.set(mode, key, M.send_and_close, map_opts)
    end
  end
end

---@param parent_win number
---@param height number
---@return table
local function overlay_float_opts(parent_win, height)
  local parent_cfg = vim.api.nvim_win_get_config(parent_win)
  local winh = vim.api.nvim_win_get_height(parent_win)
  local winw = vim.api.nvim_win_get_width(parent_win)
  local common = {
    border = "rounded",
    focusable = true,
    title = " WebSocket message ",
    zindex = 200,
  }

  -- Child `relative = "win"` floats can render behind an editor-relative parent float.
  if parent_cfg.relative == "editor" then
    local parent_row = parent_cfg.row or 0
    local parent_col = parent_cfg.col or 0
    local parent_w = parent_cfg.width or winw
    local parent_h = parent_cfg.height or winh
    local parent_z = parent_cfg.zindex or 50
    return vim.tbl_extend("force", common, {
      relative = "editor",
      row = parent_row + parent_h - height - 1,
      col = parent_col + 1,
      width = math.max(20, parent_w - 2),
      height = height,
      zindex = parent_z + 100,
    })
  end

  return vim.tbl_extend("force", common, {
    win = parent_win,
    relative = "win",
    row = math.max(0, winh - height - 1),
    col = 1,
    width = math.max(20, winw - 2),
    height = height,
  })
end

function M.open()
  if M.is_open() then return end
  if not M.can_open_from_body() then return end

  local UI = require("kulala.ui")
  local parent_win = UI.get_kulala_window() or vim.api.nvim_get_current_win()
  if parent_win <= 0 then return end

  local existing = vim.fn.bufnr(OVERLAY_NAME)
  if existing > 0 then vim.api.nvim_buf_delete(existing, { force = true }) end

  local winh = vim.api.nvim_win_get_height(parent_win)
  local height = math.min(6, math.max(3, winh - 2))

  local float = Float.create(
    { "" },
    vim.tbl_extend("force", {
      name = OVERLAY_NAME,
      bo = { filetype = "kulala_ws_input", modifiable = true },
    }, overlay_float_opts(parent_win, height))
  )

  state = { buf = float.buf, win = float.win, parent_win = parent_win }
  opening = true
  bind_overlay_keymaps(float.buf)
  vim.schedule(function()
    opening = false
    if not M.is_open() then return end
    vim.api.nvim_set_current_win(state.win)
    vim.cmd.startinsert()
  end)
end

---Kulala UI keymap: open overlay from body view, or send when overlay is focused.
function M.on_send_keymap()
  if M.is_open() then
    M.send_and_close()
    return
  end
  if M.can_open_from_body() then
    M.open()
    return
  end
  WEBSOCKET.send()
end

---@return string send_key
---@return string close_key
function M.format_welcome_keys()
  local send = kulala_keymap_keys("Send WS message")[1] or "<S-CR>"
  local close = kulala_keymap_keys("Close")[1] or "q"
  return send, close
end

return M
