local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")

local M = {}

local UI_ID = "kulala://ui"

local config = CONFIG.get_config()

local get_buffer = function()
  -- Iterate through all buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    -- Get the buffer name
    local name = vim.api.nvim_buf_get_name(buf)
    -- Check if the name matches
    if name == UI_ID then
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
    -- if the window path is the same as the UI_ID and the buffer exists
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

local function set_buffer_contents(contents, formatter)
  if buffer_exists() then
    local buf = get_buffer()
    clear_buffer()
    local lines = vim.split(contents, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    if formatter ~= nil then
      vim.api.nvim_buf_set_option(buf, "filetype", formatter)
    else
      vim.api.nvim_buf_set_option(buf, "filetype", "plaintext")
    end
  end
end

local format_result = function(formatter, contents)
  local cmd = {}
  local cmd_exists = false
  if formatter == "json" then
    cmd = { "jq", "." }
    cmd_exists = FS.command_exists("jq")
  elseif formatter == "xml" then
    cmd = { "xmllint", "--format", "-" }
    cmd_exists = FS.command_exists("xmllint")
  elseif formatter == "html" then
    cmd = { "xmllint", "--format", "--html", "-" }
    cmd_exists = FS.command_exists("xmllint")
  end
  if not cmd_exists then
    return contents
  end
  return vim.system(cmd, { stdin = contents, text = true }):wait().stdout
end

local function exec_cmd(cmd)
  return vim.system(cmd, { text = true }):wait().stdout
end

local open_buffer = function()
  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit " .. UI_ID)
  vim.cmd("setlocal buftype=nofile")
  vim.api.nvim_set_current_win(prev_win)
end

M.run = function(result)
  if buffer_exists() then
    if result.formatter then
      set_buffer_contents(format_result(result.formatter, exec_cmd(result.cmd)), result.formatter)
    else
      set_buffer_contents(exec_cmd(result.cmd), result.formatter)
    end
  else
    open_buffer()
    if result.formatter then
      set_buffer_contents(format_result(result.formatter, exec_cmd(result.cmd)), result.formatter)
    else
      set_buffer_contents(exec_cmd(result.cmd), result.formatter)
    end
  end
end

return M

