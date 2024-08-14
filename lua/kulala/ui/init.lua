local WINBAR = require("kulala.ui.winbar")
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local INLAY = require("kulala.inlay")
local PARSER = require("kulala.parser")
local CMD = require("kulala.cmd")
local FS = require("kulala.utils.fs")
local DB = require("kulala.db")
local INT_PROCESSING = require("kulala.internal_processing")
local FORMATTER = require("kulala.formatter")
local M = {}

local get_win = function()
  -- Iterate through all windows in current tab
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    -- Check if the name matches
    if name == GLOBALS.UI_ID then
      return win
    end
  end
  -- Return nil if no windows is found with the given buffer name
  return nil
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

---This makes sure to replace the buffer with a new one
---This is necessary to prevent bugs like this:
---https://github.com/mistweaverco/kulala.nvim/issues/128
local replace_buffer = function()
  local old_bufnr = get_buffer()

  local new_bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_option_value("buftype", "nofile", {
    buf = new_bufnr,
  })

  if old_bufnr ~= nil then
    for _, win in ipairs(vim.fn.win_findbuf(old_bufnr)) do
      vim.api.nvim_win_set_buf(win, new_bufnr)
    end

    vim.api.nvim_buf_delete(old_bufnr, { force = true })
  end

  -- Set the buffer name to the UI_ID after we have deleted the old buffer
  vim.api.nvim_buf_set_name(new_bufnr, GLOBALS.UI_ID)

  return new_bufnr
end

local open_buffer = function()
  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit " .. GLOBALS.UI_ID)
  if CONFIG.get().winbar then
    WINBAR.create_winbar(get_win(), get_buffer())
  end
  vim.api.nvim_set_current_win(prev_win)
end

local close_buffer = function()
  vim.cmd("bdelete! " .. GLOBALS.UI_ID)
end

local function buffer_exists()
  return get_buffer() ~= nil
end

-- Create an autocmd to delete the buffer when the window is closed
-- This is necessary to prevent the buffer from being left behind
-- when the window is closed
local augroup = vim.api.nvim_create_augroup("kulala_window_closed", { clear = true })
vim.api.nvim_create_autocmd("WinClosed", {
  group = augroup,
  callback = function(args)
    -- if the window path is the same as the GLOBALS.UI_ID and the buffer exists
    if args.buf == get_buffer() then
      vim.api.nvim_buf_delete(get_buffer(), { force = true })
    end
  end,
})

local function set_buffer_contents(contents, ft)
  if buffer_exists() then
    local buf = replace_buffer()
    local lines = vim.split(contents, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    if ft ~= nil then
      vim.bo[buf].filetype = ft
    else
      vim.bo[buf].filetype = "text"
    end
  end
end

local function pretty_ms(ms)
  return string.format("%.2fms", ms)
end

M.copy = function()
  local result = PARSER:parse()
  local cmd_table = {}
  local skip_arg = false
  for idx, v in ipairs(result.cmd) do
    if string.sub(v, 1, 1) == "-" or idx == 1 then
      -- remove headers and body output to file
      if v == "-o" or v == "-D" then
        skip_arg = true
      else
        table.insert(cmd_table, v)
      end
    else
      if skip_arg == false then
        table.insert(cmd_table, vim.fn.shellescape(v))
      else
        skip_arg = false
      end
    end
  end
  local cmd = table.concat(cmd_table, " ")
  vim.fn.setreg("+", cmd)
  vim.notify("Copied to clipboard", vim.log.levels.INFO)
end

M.open = function()
  local linenr = INLAY.get_current_line_number()
  INLAY:show_loading(linenr)
  local result = PARSER:parse()
  vim.schedule(function()
    local start = vim.loop.hrtime()
    CMD.run_parser(result, function(success)
      if not success then
        INLAY:show_error(linenr)
        return
      else
        local elapsed = vim.loop.hrtime() - start
        local elapsed_ms = pretty_ms(elapsed / 1e6)
        INLAY:show_done(linenr, elapsed_ms)
        if not buffer_exists() then
          open_buffer()
        end
        if CONFIG.get().default_view == "body" then
          M.show_body()
          if CONFIG.get().winbar then
            WINBAR.toggle_winbar_tab(get_win(), "body")
          end
        elseif CONFIG.get().default_view == "headers" then
          M.show_headers()
          if CONFIG.get().winbar then
            WINBAR.toggle_winbar_tab(get_win(), "headers")
          end
        else
          M.show_headers_body()
          if CONFIG.get().winbar then
            WINBAR.toggle_winbar_tab(get_win(), "headers_body")
          end
        end
      end
    end)
  end)
end

M.close = function()
  if buffer_exists() then
    close_buffer()
  end
  local ext = vim.fn.expand("%:e")
  if ext == "http" or ext == "rest" then
    vim.cmd("bdelete")
  end
end

M.show_body = function()
  if FS.file_exists(GLOBALS.BODY_FILE) then
    if not buffer_exists() then
      open_buffer()
    end
    local body = FS.read_file(GLOBALS.BODY_FILE)
    local contenttype = INT_PROCESSING.get_config_contenttype()
    if contenttype.formatter then
      body = FORMATTER.format(contenttype.formatter, body)
    end
    set_buffer_contents(body, contenttype.ft)
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
    h = h:gsub("\r\n", "\n")
    set_buffer_contents(h, "text")
  else
    vim.notify("No headers found", vim.log.levels.WARN)
  end
end

M.show_headers_body = function()
  if FS.file_exists(GLOBALS.HEADERS_FILE) and FS.file_exists(GLOBALS.BODY_FILE) then
    if not buffer_exists() then
      open_buffer()
    end
    local h = FS.read_file(GLOBALS.HEADERS_FILE)
    h = h:gsub("\r\n", "\n")
    local body = FS.read_file(GLOBALS.BODY_FILE)
    local contenttype = INT_PROCESSING.get_config_contenttype()
    if contenttype.formatter then
      body = FORMATTER.format(contenttype.formatter, body)
    end
    set_buffer_contents(h .. "\n" .. body, contenttype.ft)
  else
    vim.notify("No headers or body found", vim.log.levels.WARN)
  end
end

M.replay = function()
  local result = DB.data.current_request
  if result == nil then
    vim.notify("No request to replay", vim.log.levels.WARN, { title = "kulala" })
    return
  end
  vim.schedule(function()
    CMD.run_parser(result, function(success)
      if not success then
        vim.notify("Failed to replay request", vim.log.levels.ERROR, { title = "kulala" })
        return
      else
        if not buffer_exists() then
          open_buffer()
        end
        if CONFIG.get().default_view == "body" then
          M.show_body()
          if CONFIG.get().winbar then
            WINBAR.toggle_winbar_tab(get_win(), "body")
          end
        else
          M.show_headers()
          if CONFIG.get().winbar then
            WINBAR.toggle_winbar_tab(get_win(), "headers")
          end
        end
      end
    end)
  end)
end

M.scratchpad = function()
  vim.cmd("e " .. GLOBALS.SCRATCHPAD_ID)
  vim.cmd("setlocal buftype=nofile")
  vim.cmd("setlocal filetype=http")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, CONFIG.get().scratchpad_default_contents)
end

M.toggle_headers = function()
  local cfg = CONFIG.get()
  if cfg.default_view == "headers" then
    cfg.default_view = "body"
  else
    cfg.default_view = "headers"
  end
  CONFIG.set(cfg)
  if cfg.default_view == "body" then
    M.show_body()
    if cfg.winbar then
      WINBAR.toggle_winbar_tab(get_win(), "body")
    end
  else
    M.show_headers()
    if cfg.winbar then
      WINBAR.toggle_winbar_tab(get_win(), "headers")
    end
  end
end

return M
