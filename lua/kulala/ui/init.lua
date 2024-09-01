local UICallbacks = require("kulala.ui.callbacks")
local WINBAR = require("kulala.ui.winbar")
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local INLAY = require("kulala.inlay")
local PARSER = require("kulala.parser")
local CURL_PARSER = require("kulala.parser.curl")
local CMD = require("kulala.cmd")
local FS = require("kulala.utils.fs")
local DB = require("kulala.db")
local INT_PROCESSING = require("kulala.internal_processing")
local FORMATTER = require("kulala.formatter")
local TS = require("kulala.parser.treesitter")
local Logger = require("kulala.logger")
local AsciiUtils = require("kulala.utils.ascii")
local Inspect = require("kulala.parser.inspect")
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
  local callbacks = UICallbacks.get("on_replace_buffer")
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

  for _, callback in ipairs(callbacks) do
    callback(old_bufnr, new_bufnr)
  end
  return new_bufnr
end

local open_buffer = function()
  local prev_win = vim.api.nvim_get_current_win()
  local sd = CONFIG.get().split_direction == "vertical" and "vsplit" or "split"
  vim.cmd(sd .. " " .. GLOBALS.UI_ID)
  if CONFIG.get().winbar then
    WINBAR.create_winbar(get_win())
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

---Prints the parsed Request table into current buffer - uses nvim_put
local function print_http_spec(spec)
  local lines = {}
  local idx = 1

  lines[idx] = spec.method .. " " .. spec.url
  if spec.http_version ~= "" then
    lines[idx] = lines[idx] .. " " .. spec.http_version
  end
  for header, value in pairs(spec.headers) do
    idx = idx + 1
    lines[idx] = header .. ": " .. value
  end
  if spec.body ~= "" then
    idx = idx + 1
    lines[idx] = ""
    -- FIXME: broken for multi-line body
    lines[idx + 1] = spec.body
  end
  vim.api.nvim_put(lines, "l", false, false)
end

M.copy = function()
  local result = PARSER.parse()
  local cmd_table = {}
  local skip_arg = false
  for idx, v in ipairs(result.cmd) do
    if string.sub(v, 1, 1) == "-" or idx == 1 then
      -- remove headers and body output to file
      -- remove --cookie-jar
      if v == "-o" or v == "-D" or v == "--cookie-jar" or v == "-w" then
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

M.from_curl = function()
  local clipboard = vim.fn.getreg("+")
  local spec = CURL_PARSER.parse(clipboard)
  if spec == nil then
    Logger.error("Failed to parse curl command")
    return
  end
  print_http_spec(spec)
end

M.open = function()
  INLAY.clear()
  vim.schedule(function()
    local start = vim.loop.hrtime()
    local _, requests = PARSER.get_document()
    local req = PARSER.get_request_at(requests)
    if req == nil then
      Logger.error("No request found")
      return
    end
    if req.show_icon_line_number then
      INLAY:show_loading(req.show_icon_line_number)
    end
    CMD.run_parser(req, function(success)
      if not success then
        if req.show_icon_line_number then
          INLAY:show_error(req.show_icon_line_number)
        end
        return
      else
        local elapsed = vim.loop.hrtime() - start
        local elapsed_ms = pretty_ms(elapsed / 1e6)
        if req.show_icon_line_number then
          INLAY:show_done(req.show_icon_line_number, elapsed_ms)
        end
        if not buffer_exists() then
          open_buffer()
        end

        local default_view = CONFIG.get().default_view
        if default_view == "body" then
          M.show_body()
        elseif default_view == "headers" then
          M.show_headers()
        elseif default_view == "headers_body" then
          M.show_headers_body()
        elseif default_view == "script_output" then
          M.show_script_output()
        elseif CONFIG.get().default_view == "stats" then
          M.show_stats()
        end
      end
    end)
  end)
end

M.open_all = function()
  INLAY.clear()
  local requests
  if CONFIG:get().treesitter then
    requests = TS.get_all_requests()
  else
    _, requests = PARSER.get_document()
  end

  CMD.run_parser_all(requests, function(success, start, icon_linenr)
    if not success then
      if icon_linenr then
        INLAY:show_error(icon_linenr)
      end
      return
    else
      local elapsed = vim.loop.hrtime() - start
      local elapsed_ms = pretty_ms(elapsed / 1e6)
      if icon_linenr then
        INLAY:show_done(icon_linenr, elapsed_ms)
      end
      if not buffer_exists() then
        open_buffer()
      end
      if CONFIG.get().default_view == "body" then
        M.show_body()
      elseif CONFIG.get().default_view == "headers" then
        M.show_headers()
      elseif CONFIG.get().default_view == "headers_body" then
        M.show_headers_body()
      elseif CONFIG.get().default_view == "script_output" then
        M.show_script_output()
      elseif CONFIG.get().default_view == "stats" then
        M.show_stats()
      end
    end
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
    if CONFIG.get().winbar then
      WINBAR.toggle_winbar_tab(get_win(), "body")
    end
    CONFIG.options.default_view = "body"
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
    if CONFIG.get().winbar then
      WINBAR.toggle_winbar_tab(get_win(), "headers")
    end
    CONFIG.options.default_view = "headers"
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
    if CONFIG.get().winbar then
      WINBAR.toggle_winbar_tab(get_win(), "headers_body")
    end
    CONFIG.options.default_view = "headers_body"
  else
    vim.notify("No headers or body found", vim.log.levels.WARN)
  end
end

M.show_stats = function()
  local stats = FS.read_file(GLOBALS.STATS_FILE)
  if stats ~= nil then
    if not buffer_exists() then
      open_buffer()
    end
    stats = vim.fn.json_decode(stats)
    local diagram_lines = AsciiUtils.get_waterfall_timings(stats)
    local diagram = table.concat(diagram_lines, "\n")
    set_buffer_contents(diagram, "text")
    if CONFIG.get().winbar then
      WINBAR.toggle_winbar_tab(get_win(), "stats")
    end
    CONFIG.options.default_view = "stats"
  else
    Logger.error("No stats found")
  end
end

M.generate_ascii_header = function(text, opts)
  local default_opts = {
    max_line_length = 80,
  }
  opts = vim.tbl_extend("force", default_opts, opts or {})
  -- Function to center text within a given width, with additional spaces
  local function center_text(t, width)
    local padding = math.floor((width - #t) / 2)
    return string.rep(" ", padding) .. t .. string.rep(" ", width - #t - padding)
  end

  -- Split the text into lines if it exceeds the max_line_length
  local lines = {}
  while #text > opts.max_line_length - 4 do
    local line = text:sub(1, opts.max_line_length - 4)
    table.insert(lines, line)
    text = text:sub(opts.max_line_length - 3)
  end
  table.insert(lines, text)

  -- Create the header
  local header = {}
  local line_length = opts.max_line_length
  table.insert(header, " " .. string.rep("_", line_length - 2) .. " ")
  for _, line in ipairs(lines) do
    table.insert(header, string.format("/%s\\", string.rep(" ", line_length - 2)))
    table.insert(header, string.format("|%s|", center_text(line, line_length - 2)))
  end
  table.insert(header, string.format("\\%s/", string.rep("_", line_length - 2)))

  -- Return the header as a string
  return table.concat(header, "\n") .. "\n"
end

M.show_script_output = function()
  local pre_file_contents = FS.read_file(GLOBALS.SCRIPT_PRE_OUTPUT_FILE)
  local post_file_contents = FS.read_file(GLOBALS.SCRIPT_POST_OUTPUT_FILE)
  if pre_file_contents ~= nil or post_file_contents ~= nil then
    if not buffer_exists() then
      open_buffer()
    end
    local contents = ""
    if pre_file_contents ~= nil then
      contents = contents .. M.generate_ascii_header("Pre Script") .. "\n" .. pre_file_contents:gsub("\r\n", "\n")
    end
    if post_file_contents ~= nil then
      contents = contents .. M.generate_ascii_header("Post Script") .. "\n" .. post_file_contents:gsub("\r\n", "\n")
    end
    set_buffer_contents(contents, "text")
    if CONFIG.get().winbar then
      WINBAR.toggle_winbar_tab(get_win(), "script_output")
    end
    CONFIG.options.default_view = "script_output"
  else
    Logger.error("No script output found")
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
        elseif CONFIG.get().default_view == "headers" then
          M.show_headers()
        elseif CONFIG.get().default_view == "headers_body" then
          M.show_headers_body()
        elseif CONFIG.get().default_view == "script_output" then
          M.show_script_output()
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
  else
    M.show_headers()
  end
end

M.inspect = function()
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local content = Inspect.get_contents()

  -- Set the content of the buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  -- Set the filetype to http to enable syntax highlighting
  vim.bo[buf].filetype = "http"

  -- Get the total dimensions of the editor
  local total_width = vim.o.columns
  local total_height = vim.o.lines

  -- Calculate the content dimensions
  local content_width = 0
  for _, line in ipairs(content) do
    if #line > content_width then
      content_width = #line
    end
  end
  local content_height = #content

  -- Ensure the window doesn't exceed 80% of the total size
  local win_width = math.min(content_width, math.floor(total_width * 0.8))
  local win_height = math.min(content_height, math.floor(total_height * 0.8))

  -- Calculate the window position to center it
  local row = math.floor((total_height - win_height) / 2)
  local col = math.floor((total_width - win_width) / 2)

  -- Define the floating window configuration
  local win_config = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  -- Create the floating window with the buffer
  local win = vim.api.nvim_open_win(buf, true, win_config)

  -- Set up an autocommand to close the floating window on any buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })

  -- Map the 'q' key to close the window
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })
end

return M
