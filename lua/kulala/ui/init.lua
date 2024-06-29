local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local CFG = CONFIG.get_config()
local INLAY = require("kulala.inlay")
local PARSER = require("kulala.parser")
local CMD = require("kulala.cmd")
local FS = require("kulala.utils.fs")
local M = {}

local open_buffer = function()
  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit " .. GLOBALS.UI_ID)
  vim.cmd("setlocal buftype=nofile")
  vim.api.nvim_set_current_win(prev_win)
end

local get_buffer = function()
  -- Iterate through all buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    -- Get the buffer name
    local name = vim.api.nvim_buf_get_name(buf)
    -- Check if the name matches
    if name == GLOBALS.UI_ID then
      return buf
    end
  end
  -- Return nil if no buffer is found with the given name
  return nil
end

local function buffer_exists()
  return get_buffer() ~= nil
end

-- Create an autocmd to delete the buffer when the window is closed
-- This is necessary to prevent the buffer from being left behind
-- when the window is closed
vim.api.nvim_create_autocmd("WinClosed", {
  callback = function(args)
    -- if the window path is the same as the GLOBALS.UI_ID and the buffer exists
    if args.buf == get_buffer() then
      vim.api.nvim_buf_delete(get_buffer(), { force = true })
    end
  end,
})

local function clear_buffer()
  local buf = get_buffer()
  if buf then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  end
end

local function set_buffer_contents(contents, ft)
  if buffer_exists() then
    local buf = get_buffer()
    clear_buffer()
    local lines = vim.split(contents, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    if ft ~= nil then
      vim.api.nvim_buf_set_option(buf, "filetype", ft)
    else
      vim.api.nvim_buf_set_option(buf, "filetype", "plaintext")
    end
  end
end

local function pretty_ms(ms)
  return string.format("%.2fms", ms)
end

M.open = function()
  INLAY:show_loading()
  local result = PARSER:parse()
  vim.schedule(function()
    local start = vim.loop.hrtime()
    local result_body = CMD.run(result)
    local elapsed = vim.loop.hrtime() - start
    local elapsed_ms = pretty_ms(elapsed / 1e6)
    INLAY:show_done(elapsed_ms)
    if not buffer_exists() then
      open_buffer()
    end
    if CFG.default_view == "body" then
      M.show_body()
    else
      M.show_headers()
    end
  end)
end

M.show_body = function()
  if FS.file_exists(GLOBALS.BODY_FILE) then
    if not buffer_exists() then
      open_buffer()
    end
    local body = FS.read_file(GLOBALS.BODY_FILE)
    local ft = FS.read_file(GLOBALS.FILETYPE_FILE)
    set_buffer_contents(body, ft)
  else
    vim.notify("No body found", vim.log.levels.WARN)
  end
end

M.show_headers = function()
  if FS.file_exists(GLOBALS.HEADERS_FILE) then
    if not buffer_exists() then
      open_buffer()
    end
    local h = FS.read_file(GLOBALS.HEADERS_FILE)
    h = h:gsub('\r\n', '\n')
    set_buffer_contents(h, "plaintext")
  else
    vim.notify("No headers found", vim.log.levels.WARN)
  end
end

M.toggle_headers = function()
  if CFG.default_view == "headers" then
    CFG.default_view = "body"
  else
    CFG.default_view = "headers"
  end
  CONFIG.set_config(CFG)
  if CFG.default_view == "body" then
    M.show_body()
  else
    M.show_headers()
  end
end

return M
