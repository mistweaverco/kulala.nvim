local Config = require("kulala.config")

local M = {}

local PREV_BUF = nil
local PREV_WIN = nil
local TERM_BUF = nil
local TERM_WIN = nil
local CHAN_ID = nil
local INTERVAL_CHECK_TERM_READY = 100

local config = Config.get_config()

local function term_exists()
  if TERM_BUF == nil or vim.b[TERM_BUF] == nil then
    return false
  end
  return true
end

local function kill_terminal()
  if TERM_BUF ~= nil and vim.b[TERM_BUF] ~= nil then
    vim.api.nvim_buf_delete(TERM_BUF, { force = true })
    TERM_BUF = nil
    TERM_WIN = nil
    CHAN_ID = nil
  end
end

local function is_terminal_ready()
  if not term_exists() then
    return false
  end
  -- Check if the terminal buffer has line with contents
  local lines = vim.api.nvim_buf_get_lines(TERM_BUF, 0, -1, false)
  -- check if first line has at least one character
  if #lines == 0 or #lines[1] == 0 then
    return false
  end
  return true
end

local function get_current_shell()
  local shell = vim.o.shell
  if shell == "" then
    shell = os.getenv("SHELL")
  end
  if shell == "" then
    shell = "/bin/sh"
  end
  return shell
end

local function get_term_string()
  local shell = get_current_shell()
  if shell:find("fish") then
    return "term://fish"
  elseif shell:find("zsh") then
    return "term://zsh"
  elseif shell:find("bash") then
    return "term://bash"
  else
    return "term://sh"
  end
end

local TERM_STRING = get_term_string()

local function on_term_ready(cb)
  if is_terminal_ready() then
    cb()
  else
    vim.defer_fn(function()
      on_term_ready(cb)
    end, INTERVAL_CHECK_TERM_READY)
  end
end

M.run = function(command)
  kill_terminal()
  if not term_exists() then
    PREV_BUF = vim.api.nvim_get_current_buf()
    PREV_WIN = vim.api.nvim_get_current_win()
    vim.cmd("vsplit " .. TERM_STRING)
    vim.cmd("setlocal nobuflisted")
    TERM_BUF = vim.api.nvim_get_current_buf()
    TERM_WIN = vim.api.nvim_get_current_win()
    CHAN_ID = vim.b[TERM_BUF].terminal_job_id
    on_term_ready(function()
      vim.fn.chansend(CHAN_ID, "clear && " .. command .. "\n")
    end)
    vim.api.nvim_set_current_win(PREV_WIN)
  else
    vim.fn.chansend(CHAN_ID, "clear && " .. command .. "\n")
  end
end

return M

