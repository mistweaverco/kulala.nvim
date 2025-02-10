local WINBAR = require("kulala.ui.winbar")
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local KEYMAPS = require("kulala.config.keymaps")
local INLAY = require("kulala.inlay")
local PARSER = require("kulala.parser.request")
local CURL_PARSER = require("kulala.parser.curl")
local CMD = require("kulala.cmd")
local FS = require("kulala.utils.fs")
local DB = require("kulala.db")
local INT_PROCESSING = require("kulala.internal_processing")
local FORMATTER = require("kulala.formatter")
local Logger = require("kulala.logger")
local AsciiUtils = require("kulala.utils.ascii")
local Inspect = require("kulala.parser.inspect")

local M = {}

local function get_kulala_buffer()
  local buf = vim.fn.bufnr(GLOBALS.UI_ID)
  return buf > 0 and buf
end

local function get_kulala_window()
  local win = vim.fn.bufwinid(get_kulala_buffer() or -1)
  return win > 0 and win
end

local function get_current_line()
  return vim.fn.line(".")
end

M.close_kulala_buffer = function()
  local buf = get_kulala_buffer()
  if buf then vim.api.nvim_buf_delete(buf, { force = true }) end
end

-- Create an autocmd to delete the buffer when the window is closed
-- This is necessary to prevent the buffer from being left behind
-- when the window is closed
local function set_maps_autocommands(buf)
  KEYMAPS.setup_kulala_keymaps(buf)

  vim.api.nvim_create_autocmd("WinClosed", {
    group = vim.api.nvim_create_augroup("kulala_window_closed", { clear = true }),
    buffer = buf,
    callback = function()
      if vim.fn.bufexists(buf) > 0 then vim.api.nvim_buf_delete(buf, { force = true }) end
    end,
  })
end

local open_kulala_buffer = function(filetype)
  local buf = vim.api.nvim_create_buf(true, true)
  set_maps_autocommands(buf)

  vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })

  local win = get_kulala_window()
  if win then vim.api.nvim_win_set_buf(win, buf) end

  ---This makes sure to replace current kulala buffer with a new one
  ---This is necessary to prevent bugs like this:
  ---https://github.com/mistweaverco/kulala.nvim/issues/128
  M.close_kulala_buffer()
  vim.api.nvim_buf_set_name(buf, GLOBALS.UI_ID)

  return buf
end

local function set_buffer_contents(buf, contents, filetype)
  local lines = vim.split(contents, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = filetype
end

local function open_kulala_window(buf)
  local config = CONFIG.get()
  local previous_win, win_config

  local win = get_kulala_window()
  if win then return win end

  if config.display_mode == "float" then
    local width = math.max(vim.api.nvim_win_get_width(0) - 10, 1)
    local height = math.max(vim.api.nvim_win_get_height(0) - 10, 1)

    win_config = {
      title = "Kulala",
      title_pos = "center",
      relative = "editor",
      border = "single",
      width = width,
      height = height,
      row = math.floor(((vim.o.lines - height) / 2) - 1),
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal",
    }
  else
    win_config = { split = config.split_direction == "vertical" and "right" or "below" }
    previous_win = vim.api.nvim_get_current_win()
  end

  win = vim.api.nvim_open_win(buf, true, win_config)

  if config.display_mode == "split" then vim.api.nvim_set_current_win(previous_win) end

  return win
end

local function show(contents, filetype, mode)
  local buf = open_kulala_buffer(filetype)
  set_buffer_contents(buf, contents, filetype)

  local win = open_kulala_window(buf)

  WINBAR.toggle_winbar_tab(buf, win, mode)
  CONFIG.options.default_view = mode
end

local function format_body()
  local contenttype = INT_PROCESSING.get_config_contenttype()
  local body = FS.read_file(GLOBALS.BODY_FILE)
  local filetype

  if body and contenttype.formatter then
    body = FORMATTER.format(contenttype.formatter, body)
    filetype = contenttype.ft
  end

  return body, filetype
end

M.show_headers = function()
  local headers = FS.read_file(GLOBALS.HEADERS_FILE)

  if not headers then return Logger.warn("No headers found") end

  headers = headers:gsub("\r\n", "\n")
  show(headers, "text", "headers")
end

M.show_body = function()
  local body, filetype = format_body()

  if not body then return Logger.warn("No body found") end

  show(body, filetype, "body")
end

M.show_headers_body = function()
  local headers = FS.read_file(GLOBALS.HEADERS_FILE)
  local body, filetype = format_body()

  if not headers or not body then return Logger.warn("No headers or body found") end

  headers = headers:gsub("\r\n", "\n") .. "\n"
  show(headers .. body, filetype, "headers_body")
end

M.show_verbose = function()
  local body = format_body()
  local errors = FS.read_file(GLOBALS.ERRORS_FILE)

  if not body then return Logger.warn("No body found") end

  errors = errors and errors:gsub("\r", "") .. "\n" or ""
  show(errors .. body, "kulala_verbose_result", "verbose")
end

M.show_stats = function()
  local stats = FS.read_file(GLOBALS.STATS_FILE)

  if not stats then return Logger.warn("No stats found") end

  stats = vim.json.decode(stats)

  local diagram_lines = AsciiUtils.get_waterfall_timings(stats)
  local diagram = table.concat(diagram_lines, "\n")

  show(diagram, "text", "stats")
end

M.show_script_output = function()
  local pre_file_contents = FS.read_file(GLOBALS.SCRIPT_PRE_OUTPUT_FILE)
  local post_file_contents = FS.read_file(GLOBALS.SCRIPT_POST_OUTPUT_FILE)
  local contents = ""

  if not pre_file_contents and not post_file_contents then
    Logger.error("No script output found")
    return
  end

  contents = pre_file_contents
    and contents .. M.generate_ascii_header("Pre Script") .. "\n" .. pre_file_contents:gsub("\r\n", "\n")
  contents = post_file_contents
      and contents .. M.generate_ascii_header("Post Script") .. "\n" .. post_file_contents:gsub("\r\n", "\n")
    or contents

  show(contents, "text", "script_output")
end

M.toggle_headers = function()
  local config = CONFIG.get()
  local default_view = config.default_view

  if default_view == "headers" then
    default_view = "body"
  else
    default_view = "headers"
  end

  config.default_view = default_view
  M.open_default_view()
end

M.scratchpad = function()
  vim.cmd("e " .. GLOBALS.SCRATCHPAD_ID)
  vim.cmd("setlocal filetype=http")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, CONFIG.get().scratchpad_default_contents)
end

M.open_default_view = function()
  local default_view = CONFIG.get().default_view
  local open_view = M["show_" .. default_view]

  _ = open_view and open_view()
end

local function pretty_ms(ms)
  return string.format("%.2fms", ms)
end

M.open = function()
  M:open_all(get_current_line())
end

M.open_all = function(_, line_nr)
  line_nr = line_nr or 0

  DB.set_current_buffer()
  INLAY.clear()

  CMD.run_parser(nil, line_nr, function(success, start_time, icon_linenr)
    if success then
      ---@diagnostic disable-next-line: undefined-field
      local elapsed = vim.loop.hrtime() - start_time
      local elapsed_ms = pretty_ms(elapsed / 1e6)

      INLAY:show_done(icon_linenr, elapsed_ms)
    elseif success == nil then
      INLAY:show_loading(icon_linenr)
    elseif success == false then
      INLAY:show_error(icon_linenr)
      return
    end

    M.open_default_view()
    return true
  end)
end

M.replay = function()
  local last_request = DB.global_find_unique("replay")

  if not last_request then return Logger.warn("No request to replay") end

  CMD.run_parser({ last_request }, nil, function(success)
    if success == false then
      Logger.error("Unable to replay last request")
      return
    end

    M.open_default_view()
    return true
  end)
end

M.close = function()
  M.close_kulala_buffer()

  local ext = vim.fn.expand("%:e")
  if ext == "http" or ext == "rest" then vim.api.nvim_buf_delete(vim.fn.bufnr(), {}) end
end

M.copy = function()
  local request = PARSER.parse()
  if not request then return Logger.error("No request found") end

  local skip_flags = { "-o", "-D", "--cookie-jar", "-w", "--data-binary" }
  local previous_flag

  local cmd = vim.iter(request.cmd):fold("", function(cmd, flag)
    if not vim.tbl_contains(skip_flags, flag) and not vim.tbl_contains(skip_flags, previous_flag) then
      flag = (flag:find("^%-") or not previous_flag) and flag or vim.fn.shellescape(flag)
      cmd = cmd .. flag .. " "
    end

    if previous_flag == "--data-binary" then
      local body = FS.read_file(flag:sub(2), true) or "[could not read file]"
      cmd = ('%s--data-binary "%s" '):format(cmd, body)
    end

    previous_flag = flag
    return cmd
  end)

  vim.fn.setreg("+", vim.trim(cmd))
  Logger.info("Copied to clipboard")
end

---Prints the parsed Request table into current buffer - uses nvim_put
local function print_http_spec(spec, curl)
  local lines = {}

  table.insert(lines, "# " .. curl)

  if spec.http_version ~= "" then
    table.insert(lines, spec.method .. " " .. spec.url .. " " .. spec.http_version)
  else
    table.insert(lines, spec.method .. " " .. spec.url)
  end

  for header, value in pairs(spec.headers) do
    table.insert(lines, header .. ": " .. value)
  end

  if spec.body ~= "" then
    table.insert(lines, "")
    -- FIXME: broken for multi-line body
    table.insert(lines, spec.body)
  end
  vim.api.nvim_put(lines, "l", false, false)
end

M.from_curl = function()
  local clipboard = vim.fn.getreg("+")
  local spec, curl = CURL_PARSER.parse(clipboard)

  if not spec then
    Logger.error("Failed to parse curl command")
    return
  end
  -- put the curl command in the buffer as comment
  print_http_spec(spec, curl)
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

M.inspect = function()
  local inspect_name = "kulala://inspect"

  local content = Inspect.get_contents()
  if #content == 0 then return end

  -- Create a new buffer
  local buf = vim.fn.bufnr(inspect_name)

  _ = buf > 0 and vim.api.nvim_buf_delete(buf, { force = true })
  buf = vim.api.nvim_create_buf(false, true)

  -- Set the content of the buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  -- Set the filetype to http to enable syntax highlighting
  vim.bo[buf].filetype = "http"
  vim.api.nvim_buf_set_name(buf, inspect_name)

  -- Get the total dimensions of the editor
  local total_width = vim.o.columns
  local total_height = vim.o.lines

  -- Calculate the content dimensions
  local content_width = 0
  for _, line in ipairs(content) do
    if #line > content_width then content_width = #line end
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
      vim.api.nvim_buf_delete(buf, { force = true })
    end,
  })
end

return M
