local AsciiUtils = require("kulala.utils.ascii")
local CMD = require("kulala.cmd")
local CONFIG = require("kulala.config")
local CURL_PARSER = require("kulala.parser.curl")
local DB = require("kulala.db")
local FORMATTER = require("kulala.formatter")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local INLAY = require("kulala.inlay")
local INT_PROCESSING = require("kulala.internal_processing")
local Inspect = require("kulala.parser.inspect")
local KEYMAPS = require("kulala.config.keymaps")
local Logger = require("kulala.logger")
local PARSER = require("kulala.parser.request")
local UiHighlight = require("kulala.ui.highlight")
local WINBAR = require("kulala.ui.winbar")

local M = {}

local function get_kulala_buffer()
  local buf = vim.fn.bufnr(GLOBALS.UI_ID)
  return buf > 0 and buf
end

local function get_kulala_window()
  local win = vim.fn.win_findbuf(get_kulala_buffer() or -1)[1]
  return win and win
end

---Get the current line number, 1-indexed
local function get_current_line()
  return vim.fn.line(".")
end

local function get_current_response_pos()
  local responses = DB.global_update().responses
  return DB.global_update().current_response_pos or #responses
end

local function get_current_response()
  local responses = DB.global_update().responses
  return responses[get_current_response_pos()]
    or setmetatable({}, {
      __index = function()
        return ""
      end,
    })
end

local function set_current_response(response_pos)
  DB.global_update().current_response_pos = response_pos
end

M.close_kulala_buffer = function()
  local buf = get_kulala_buffer()
  if buf then vim.api.nvim_buf_delete(buf, { force = true }) end
end

-- Create an autocmd to delete the buffer when the window is closed
-- This is necessary to prevent the buffer from being left behind
-- when the window is closed
local function set_maps_autocommands(buf)
  CONFIG.get().kulala_keymaps = KEYMAPS.setup_kulala_keymaps(buf)

  vim.api.nvim_create_autocmd("WinClosed", {
    group = vim.api.nvim_create_augroup("kulala_window_closed", { clear = true }),
    buffer = buf,
    callback = function()
      if vim.fn.bufexists(buf) > 0 then vim.api.nvim_buf_delete(buf, { force = true }) end
    end,
  })
end

local open_kulala_buffer = function(filetype)
  local buf = get_kulala_buffer()

  if not buf then
    buf = vim.api.nvim_create_buf(true, true)
    set_maps_autocommands(buf)

    vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
    vim.api.nvim_buf_set_name(buf, GLOBALS.UI_ID)
  end

  local win = get_kulala_window()
  if win then vim.api.nvim_win_set_buf(win, buf) end

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

local function pretty_ms(ms)
  return string.format("%.2fms", ms)
end

local function set_current_response_data(buf)
  local config = CONFIG.get()
  if not config.ui.show_request_summary then return end

  local responses = DB.global_update().responses
  local response = get_current_response()
  local idx = get_current_response_pos()
  local duration = response.duration == "" and 0 or pretty_ms(response.duration / 1e6)

  local data = vim
    .iter({
      {
        "Request: "
          .. idx
          .. "/"
          .. #responses
          .. "  Status: "
          .. response.status
          .. "  Duration: "
          .. duration
          .. "  Time: "
          .. response.time,
      },
      { "URL: " .. response.method .. " " .. response.url },
      { "Buffer: " .. response.buf_name .. "::" .. response.line },
      { "" },
    })
    :flatten()
    :totable()

  vim.api.nvim_buf_set_lines(buf, 0, 0, false, data)
  UiHighlight.highlight_range(
    get_kulala_buffer(),
    0,
    { row = 0, col = 0 },
    { row = 2, col = -1 },
    config.ui.summaryTextHighlight
  )
end

local function show(contents, filetype, mode)
  local buf = open_kulala_buffer(filetype)
  set_buffer_contents(buf, contents, filetype)
  set_current_response_data(buf)

  local win = open_kulala_window(buf)

  WINBAR.toggle_winbar_tab(buf, win, mode)
  CONFIG.options.default_view = mode
end

local function format_body()
  local headers = get_current_response().headers
  local body = get_current_response().body
  local contenttype = INT_PROCESSING.get_config_contenttype(headers)
  local filetype

  if body and contenttype.formatter then
    body = FORMATTER.format(contenttype.formatter, body)
    filetype = contenttype.ft
  end

  return body, filetype
end

M.show_headers = function()
  local headers = get_current_response().headers
  show(headers, "text", "headers")
end

M.show_body = function()
  local body, filetype = format_body()
  show(body, filetype, "body")
end

M.show_headers_body = function()
  local headers = get_current_response().headers
  local body, filetype = format_body()
  show(headers .. body, filetype, "headers_body")
end

M.show_verbose = function()
  local body = format_body()
  local errors = get_current_response().errors
  show(errors .. "\n" .. body, "kulala_verbose_result", "verbose")
end

M.show_stats = function()
  local stats = get_current_response().stats
  local diagram

  if stats then
    stats = vim.json.decode(stats)

    local diagram_lines = AsciiUtils.get_waterfall_timings(stats)
    diagram = table.concat(diagram_lines, "\n")
  end

  show(diagram or "", "text", "stats")
end

M.show_script_output = function()
  local pre_file_contents = get_current_response().script_pre_output
  local post_file_contents = get_current_response().script_post_output

  local contents = "===== Pre Script Output =====================================\n\n" .. pre_file_contents
  contents = contents .. "\n\n===== Post Script Output ====================================\n\n" .. post_file_contents

  show(contents, "text", "script_output")
end

M.show_next = function()
  local responses = DB.global_update().responses
  local current_pos = get_current_response_pos()
  local next = current_pos == #responses and current_pos or current_pos + 1

  set_current_response(next)
  M.open_default_view()
end

M.show_previous = function()
  local current_pos = get_current_response_pos()
  local previous = current_pos <= 1 and current_pos or current_pos - 1

  set_current_response(previous)
  M.open_default_view()
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
  local open_view = type(default_view) == "function" and default_view or M["show_" .. default_view]

  _ = open_view and open_view(get_current_response())
end

M.open = function()
  M:open_all(vim.api.nvim_get_mode().mode == "V" and 0 or get_current_line())
end

M.open_all = function(_, line_nr)
  line_nr = line_nr or 0

  DB.set_current_buffer()
  INLAY.clear()

  CMD.run_parser(nil, line_nr, function(success, duration, icon_linenr)
    if success then
      local elapsed_ms = pretty_ms(duration / 1e6)

      INLAY.show("done", icon_linenr, elapsed_ms)
    elseif success == nil then
      INLAY.show("loading", icon_linenr)
    elseif success == false then
      INLAY.show("error", icon_linenr)
      return
    end

    set_current_response(#DB.global_update().responses)
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

  local headers = vim.tbl_keys(spec.headers)
  table.sort(headers)

  vim.iter(headers):each(function(header)
    table.insert(lines, header .. ": " .. spec.headers[header])
  end)

  if spec.body ~= "" then
    table.insert(lines, "")
    vim.iter(spec.body):each(function(line)
      if spec.body[#spec.body] == line then
        table.insert(lines, line)
      else
        table.insert(lines, line .. "&")
      end
    end)
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
