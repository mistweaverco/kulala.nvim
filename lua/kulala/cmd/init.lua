local Config = require("kulala.config")

local M = {}

local UI_ID = "kulala://ui"
local PREV_BUF = nil
local PREV_WIN = nil
local UI_BUF = nil
local UI_WIN = nil

local config = Config.get_config()

-- checks if the buffer exists with the given name (UI_ID)
local function buffer_exists()
  if vim.fn.bufwinnr(UI_ID) > 0 then
    return true
  end
  return false
end

local function clear_buffer()
  if buffer_exists() then
    vim.api.nvim_buf_set_lines(UI_BUF, 0, -1, false, {})
  end
end

local function kill_buffer()
  if buffer_exists() then
    vim.api.nvim_buf_delete(UI_BUF, { force = true })
    UI_BUF = nil
    UI_WIN = nil
  end
end

local function set_buffer_contents(contents, formatter)
  if buffer_exists() then
    clear_buffer()
    local lines = vim.split(contents, "\n")
    vim.api.nvim_buf_set_lines(UI_BUF, 0, -1, false, lines)
    if formatter ~= nil then
      vim.api.nvim_buf_set_option(UI_BUF, "filetype", formatter)
    else
      vim.api.nvim_buf_set_option(UI_BUF, "filetype", "plaintext")
    end
  end
end

local format_result = function(formatter, contents)
  local cmd = {}
  if formatter == "json" then
    cmd = { "jq", "." }
  end
  return vim.system(cmd, { stdin = contents, text = true }):wait().stdout
end

local function exec_cmd(cmd)
  return vim.system(cmd, { text = true }):wait().stdout
end

M.run = function(ast)
  if buffer_exists() then
    if ast.formatter then
      set_buffer_contents(format_result(ast.formatter, exec_cmd(ast.cmd)), ast.formatter)
    else
      set_buffer_contents(exec_cmd(ast.cmd), ast.formatter)
    end
  else
    PREV_BUF = vim.api.nvim_get_current_buf()
    PREV_WIN = vim.api.nvim_get_current_win()
    vim.cmd("vsplit kulala://ui")
    vim.cmd("setlocal nobuflisted")
    vim.cmd("setlocal bufhidden=hide")
    vim.cmd("setlocal buftype=nofile")
    UI_BUF = vim.api.nvim_get_current_buf()
    UI_WIN = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(PREV_WIN)
    if ast.formatter then
      set_buffer_contents(format_result(ast.formatter, exec_cmd(ast.cmd)), ast.formatter)
    else
      set_buffer_contents(exec_cmd(ast.cmd), ast.formatter)
    end
  end
end

return M

