local AsciiUtils = require("kulala.utils.ascii")
local CMD = require("kulala.cmd")
local CONFIG = require("kulala.config")
local CURL_PARSER = require("kulala.parser.curl")
local DB = require("kulala.db")
local DOC_PARSER = require("kulala.parser.document")
local Ext_processing = require("kulala.external_processing")
local FORMATTER = require("kulala.formatter")
local FS = require("kulala.utils.fs")
local Float = require("kulala.ui.float")
local GLOBALS = require("kulala.globals")
local INLAY = require("kulala.inlay")
local INT_PROCESSING = require("kulala.internal_processing")
local Inspect = require("kulala.parser.inspect")
local KEYMAPS = require("kulala.config.keymaps")
local Logger = require("kulala.logger")
local PARSER = require("kulala.parser.request")
local REPORT = require("kulala.ui.report")
local UI_utils = require("kulala.ui.utils")
local WINBAR = require("kulala.ui.winbar")
local Xmas = require("kulala.ui.xmas")

local M = {}

---@class kulala.ui.win_config: vim.api.keyset.win_config
---@field bo table<string, any> Buffer options
---@field wo table<string, any> Window options

local is_initialized = function()
  return CONFIG.get().initialized
end

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

---@return Response
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
  local config = CONFIG.get()
  local buf = get_kulala_buffer()

  if not buf then
    buf = vim.api.nvim_create_buf(false, true)
    set_maps_autocommands(buf)

    local bo = vim.tbl_extend("keep", config.ui.win_opts.bo or {}, {
      filetype = filetype,
      buftype = "nofile",
    })

    vim.iter(bo):each(function(key, value)
      local status, error = pcall(vim.api.nvim_set_option_value, key, value, { buf = buf })
      if not status then Logger.error("Failed to set buffer option `" .. key .. "`: " .. (error or "")) end
    end)

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
  local win_config

  local win = get_kulala_window()
  if win then return win end

  local request_win = vim.fn.win_findbuf(DB.get_current_buffer())[1] or vim.api.nvim_get_current_win()

  local win_opts = vim.deepcopy(config.ui.win_opts or {})
  local wo = win_opts.wo or {}

  win_opts.bo = nil
  win_opts.wo = nil

  if config.display_mode == "float" then
    local width = math.max(vim.o.columns - 10, 1)
    local height = math.max(vim.o.lines - 10, 1)

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
    win_config = { split = config.split_direction == "vertical" and "right" or "below", win = request_win }
  end

  win_config = vim.tbl_extend("force", win_config, win_opts)
  win = vim.api.nvim_open_win(buf, false, win_config)

  wo = vim.tbl_extend("keep", wo, {
    signcolumn = "yes:1",
    number = false,
    relativenumber = false,
    foldmethod = "indent",
  })

  vim.iter(wo):each(function(key, value)
    local status, error = pcall(vim.api.nvim_set_option_value, key, value, { win = win, scope = "local" })
    if not status then Logger.error("Failed to set window option `" .. key .. "`: " .. (error or "")) end
  end)

  _ = config.display_mode == "float" and vim.api.nvim_set_current_win(win)

  return win
end

local function hide_progress()
  local footer = vim.fn.bufnr("kulala://requests_progress")
  if footer > 0 then vim.api.nvim_buf_delete(footer, { force = true }) end
end

local function show_progress()
  if #CMD.queue.tasks == 0 then return hide_progress() end

  local row_offset = vim.fn.bufwinnr("kulala://news_footer") > 0 and 3 or 2
  local message = ("Running.. %s/%s"):format(CMD.queue.done, CMD.queue.total)
  message = message .. " - press <C-c> to cancel  "

  Float.create_window_footer(message, {
    buf = get_kulala_buffer(),
    win = get_kulala_window(),
    name = "kulala://requests_progress",
    row_offset = row_offset,
    auto_close = true,
  })
end

local function show(contents, filetype, mode)
  filetype = filetype and filetype .. ".kulala_ui" or "text.kulala_ui"
  local buf = open_kulala_buffer(filetype)

  set_buffer_contents(buf, contents, filetype)
  _ = mode ~= "report" and REPORT.set_response_summary(buf)

  local win = open_kulala_window(buf)
  local lnum = mode == "report" and vim.api.nvim_buf_line_count(buf) or 4

  vim.fn.win_execute(win, "normal! " .. lnum .. "G")

  WINBAR.toggle_winbar_tab(buf, win, mode)
  CONFIG.options.default_view = mode

  M.show_news_footer()
  show_progress()
end

local function format_body(view)
  local headers = get_current_response().headers
  local body = get_current_response().body

  local contenttype = INT_PROCESSING.get_config_contenttype(headers, view)
  local filetype

  if body and contenttype.formatter then
    filetype = contenttype.ft
    body = FORMATTER.format(filetype, contenttype.formatter, body, { verbose = false })
  end

  return body, filetype or contenttype.ft
end

local function update_filter()
  local filter = vim.api.nvim_get_current_line()
  if not filter:find("JQ Filter") then return end

  filter = vim.trim(filter:sub(12))
  Ext_processing.jq(filter, get_current_response())
  M.show_body()
end

M.toggle_filter = function()
  local buf = get_kulala_buffer()
  local row = 4

  if vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]:find("JQ Filter") then
    return vim.api.nvim_buf_set_lines(buf, row - 1, row + 1, false, {})
  end

  local filter = { "JQ Filter: " .. (get_current_response().filter or ""), "" }

  vim.api.nvim_buf_set_lines(buf, row, row, false, filter)

  UI_utils.highlight_range(buf, 0, { row, 0 }, { row, 12 }, "Question")
  UI_utils.highlight_range(buf, 0, { row, 10 }, { row, -1 }, "Special")
end

local function jump_to_response()
  local responses = DB.global_update().responses
  local win = vim.fn.bufwinid(get_current_response().buf)

  if CONFIG.get().default_view == "report" then
    local lnum = tonumber(vim.api.nvim_get_current_line():match("^%s*%d+"))
    if not lnum then return end

    for i = #responses, 1, -1 do
      if responses[i].line == lnum then
        set_current_response(i)
        break
      end
    end

    M.show_body()
  elseif win > 0 then
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { get_current_response().line, 0 })

    win = get_kulala_window()
    _ = vim.api.nvim_win_get_config(win).relative == "editor" and vim.api.nvim_win_close(win, true)
  end
end

M.show_headers = function()
  local headers = get_current_response().headers
  show(headers, "text", "headers")
end

M.show_body = function()
  local body, filetype = format_body()
  show(body, filetype, "body")
  _ = get_current_response().filter and M.toggle_filter()
end

M.show_headers_body = function()
  local headers = get_current_response().headers
  local body, filetype = format_body()
  show(headers .. body, filetype, "headers_body")
end

M.show_verbose = function()
  local body, filetype = format_body("verbose")
  local errors = get_current_response().errors
  show(errors .. "\n" .. body, filetype, "verbose")
end

M.show_stats = function()
  local stats = get_current_response().stats
  local diagram

  if stats.timings then
    local diagram_lines = AsciiUtils.get_waterfall_timings(stats.timings)
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

M.show_report = function()
  local report, highlights = REPORT.generate_requests_report()
  show(table.concat(report or {}, "\n"), "text", "report")
  UI_utils.highlight_buffer(get_kulala_buffer(), 0, highlights or {}, 100)
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

M.clear_responses_history = function()
  DB.global_update().responses = {}
  DB.global_update().current_response_pos = 0
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

M.toggle_display_mode = function()
  local config = CONFIG.get()
  local display_mode = config.display_mode

  if display_mode == "float" then
    display_mode = "split"
  else
    display_mode = "float"
  end

  config.display_mode = display_mode
  M.close_kulala_buffer()
  M.open_default_view()
end

M.show_help = function()
  local keymaps = CONFIG.get().kulala_keymaps
  local help = vim.split(
    [[
  Kulala Help
  ===========
    ]],
    "\n"
  )

  vim.iter(keymaps):each(function(keymap, value)
    table.insert(help, ("  - %s: `%s`"):format(keymap, value[1]))
  end)

  Float.create(help, {
    name = "kulala_help",
    ft = "markdown",
    relative = "cursor",
    border = "rounded",
    focusable = true,
    auto_size = true,
    auto_close = true,
    close_keymaps = { "q", "<esc>", "?" },
  })
end

M.show_news_footer = function()
  if CONFIG.get().disable_news_popup then return end

  local msg

  if Xmas.is_christmas_season() then
    msg = Xmas.get_random_message()
  elseif DB.settings.news_ver ~= GLOBALS.VERSION then
    msg = "Check out the latest Kulala changes with `g?`"
  else
    return
  end

  Float.create_window_footer(msg, {
    buf = get_kulala_buffer(),
    win = get_kulala_window(),
    name = "kulala://news_footer",
    row_offset = 2,
    auto_close = true,
  })
end

M.show_news = function()
  local news = FS.get_plugin_root_dir() .. "/../../NEWS.md"
  local contents = FS.read_file(news) or "No news found"
  vim.cmd("lcd " .. vim.fs.dirname(news) .. "/docs/docs")

  show(contents, "markdown", "body")
  REPORT.hide_response_summary()

  local footer = vim.fn.bufnr("kulala://news_footer")
  _ = footer > -1 and vim.api.nvim_buf_delete(footer, { force = true })

  DB.settings:write { news_ver = GLOBALS.VERSION }
end

M.scratchpad = function()
  vim.cmd("e " .. GLOBALS.SCRATCHPAD_ID)
  vim.cmd("setlocal filetype=http")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, CONFIG.get().scratchpad_default_contents)
end

M.open_default_view = function()
  local default_view = CONFIG.get().default_view
  local open_view = type(default_view) == "function" and default_view or M["show_" .. default_view]

  local status, errors = xpcall(function()
    _ = open_view and open_view(get_current_response())
  end, debug.traceback)

  if not status then Logger.error("Errors displaying response: " .. (errors or ""), 1, { report = true }) end
end

M.open = function()
  M:open_all(vim.api.nvim_get_mode().mode == "V" and 0 or get_current_line())
end

M.open_all = function(_, line_nr)
  if not is_initialized() then return Logger.error("Kulala setup is not initialized. Check the config.") end

  line_nr = line_nr or 0
  local db = DB.global_update()
  local status, elapsed_ms

  local buf = DB.set_current_buffer()
  db.previous_response_pos = #db.responses
  INLAY.clear()

  CMD.run_parser(nil, line_nr, function(success, duration, icon_linenr)
    if success then
      elapsed_ms = UI_utils.pretty_ms(duration)
      status = "done"
    else
      status = success == nil and "loading" or "error"
    end

    set_current_response(#db.responses)

    INLAY.show(buf, status, icon_linenr, elapsed_ms)
    M.open_default_view()

    return true
  end)
end

M.jump_next = function()
  local reqs = DOC_PARSER.get_document()
  local next = DOC_PARSER.get_next_request(reqs)
  if next then vim.api.nvim_win_set_cursor(0, { next.start_line, 0 }) end
end

M.jump_prev = function()
  local reqs = DOC_PARSER.get_document()
  local prev = DOC_PARSER.get_previous_request(reqs)
  if prev then vim.api.nvim_win_set_cursor(0, { prev.start_line, 0 }) end
end

M.keymap_enter = function()
  if get_current_response().method == "WS" then
    require("kulala.cmd.websocket").send()
  elseif vim.api.nvim_get_current_line():find("JQ Filter") then
    update_filter()
  else
    jump_to_response()
  end
end

M.interrupt_requests = function()
  if get_current_response().method == "WS" then return require("kulala.cmd.websocket").close() end

  CMD.queue:reset()
  INLAY.clear("kulala.loading")
  hide_progress()
end

M.replay = function()
  local last_request = DB.global_find_unique("replay")
  if not last_request then return Logger.warn("No request to replay") end

  local db = DB.global_update()

  CMD.run_parser({ last_request }, nil, function(_)
    set_current_response(#db.responses)
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

  local skip_flags = { "-o", "-D", "--cookie-jar", "-w", "--data-binary", "--data-urlencode" }
  local previous_flag

  local cmd = vim.iter(request.cmd):fold("", function(cmd, flag)
    if not vim.tbl_contains(skip_flags, flag) and not vim.tbl_contains(skip_flags, previous_flag) then
      flag = (flag:find("^%-") or not previous_flag) and flag or vim.fn.shellescape(flag)
      cmd = cmd .. flag .. " "
    end

    if previous_flag == "--data-binary" or previous_flag == "--data-urlencode" then
      local body = FS.read_file(flag:sub(2), true) or "[could not read file]"
      body = #body > 1000 and flag or body
      cmd = ("%s%s %s "):format(cmd, previous_flag, vim.fn.shellescape(body))
    end

    previous_flag = flag
    return cmd
  end)

  vim.fn.setreg("+", vim.trim(cmd))
  Logger.info("Copied to clipboard")
end

M.from_curl = function()
  local clipboard = vim.fn.getreg("+")
  local spec, curl = CURL_PARSER.parse(clipboard)

  if not spec then
    Logger.error("Failed to parse curl command")
    return
  end
  -- put the curl command in the buffer as comment
  REPORT.print_http_spec(spec, curl)
end

M.inspect = function()
  local content = Inspect.get_contents()
  if #content == 0 then return end

  Float.create(content, {
    name = "kulala://inspect",
    ft = "http",
    relative = "cursor",
    focusable = true,
    border = "rounded",
    auto_size = true,
    close_keymaps = { "q", "<esc>" },
  })
end

M.get_kulala_buffer = get_kulala_buffer
M.get_kulala_window = get_kulala_window
M.get_current_response = get_current_response
M.get_current_response_pos = get_current_response_pos

return M
