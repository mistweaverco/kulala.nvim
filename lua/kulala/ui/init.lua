local AsciiUtils = require("kulala.utils.ascii")
local CMD = require("kulala.cmd")
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local DOC_PARSER = require("kulala.parser.document")
local Ext_processing = require("kulala.external_processing")
local FS = require("kulala.utils.fs")
local Float = require("kulala.ui.float")
local GLOBALS = require("kulala.globals")
local INLAY = require("kulala.inlay")
local KEYMAPS = require("kulala.config.keymaps")
local Logger = require("kulala.logger")
local PARSER = require("kulala.parser.request")
local REPORT = require("kulala.ui.report")
local UI_utils = require("kulala.ui.utils")
local WINBAR = require("kulala.ui.winbar")

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

---Keep the UI on an existing response (e.g. live WebSocket stream) instead of using stale `previous_response_pos`.
---@param db table
---@param response_id? string
---@return boolean positioned when true
local function set_current_response_by_id(db, response_id)
  if not response_id then return false end
  for i = #db.responses, 1, -1 do
    if db.responses[i].id == response_id then
      set_current_response(i)
      return true
    end
  end
  return false
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
      filetype = "kulala_ui",
      buftype = "nofile",
      syntax = filetype,
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
  vim.bo[buf].filetype = "kulala_ui"
  vim.bo[buf].syntax = filetype
  -- wrap in pcall to avoid errors when treesitter doesn't support the filetype
  pcall(vim.treesitter.start, buf, filetype)
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
    -- INFO:
    -- Legacy options support for split direction
    -- as "vertical" and "horizontal" were previously usued to
    -- indicate split direction.
    -- We map them to the new "split" option values for backward compatibility
    local split = config.split_direction == "vertical" and "right"
      or config.split_direction == "horizontal" and "below"
      or config.split_direction
    win_config = { split = split, win = request_win }
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

  if config.display_mode == "float" then vim.api.nvim_set_current_win(win) end

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
  message = message .. " - <C-c> cancels requests (newest first)  "

  Float.create_window_footer(message, {
    buf = get_kulala_buffer(),
    win = get_kulala_window(),
    name = "kulala://requests_progress",
    row_offset = row_offset,
    auto_close = true,
  })
end

local MARKDOWN_VIEWS = {
  verbose = true,
  headers = true,
  headers_body = true,
  script_output = true,
  report = true,
}

local function show(contents, filetype, mode)
  -- Markdown views use plain `markdown` so TS/highlight plugins apply.
  local buf_ft = MARKDOWN_VIEWS[mode] and "markdown" or filetype
  if MARKDOWN_VIEWS[mode] then contents = require("kulala.ui.markdown").normalize_headings(contents) end
  local buf = open_kulala_buffer(buf_ft)

  set_buffer_contents(buf, contents, buf_ft)
  if mode ~= "report" then REPORT.set_response_summary(buf) end

  local win = open_kulala_window(buf)
  local lnum = mode == "report" and vim.api.nvim_buf_line_count(buf) or 4

  vim.fn.win_execute(win, "normal! " .. lnum .. "G")

  WINBAR.toggle_winbar_tab(buf, win, mode)
  CONFIG.options.default_view = mode

  show_progress()
end

---Prefer kulala-core `body.type` for JSON; otherwise resolve via `mediaType` or
---response headers.
---@param r Response
---@return string ft type to determine syntax highlighting
local function get_ft_from_kulala_core(r)
  if not r._kulala_core or not r._kulala_body_type then return "text" end
  if r._kulala_body_type == "json" then return "json" end
  if type(r._kulala_media_type) == "string" and r._kulala_media_type ~= "" then
    if r._kulala_media_type:find("json") then return "json" end
    if r._kulala_media_type:find("xml") then return "xml" end
  end
  return "text"
end

---Resolve body text and syntax filetype (formatting is done in kulala-core).
---@return string body text to display
---@return string filetype for syntax highlighting
local function format_body()
  local r = get_current_response()
  return r.body, get_ft_from_kulala_core(r)
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

local function parse_report_line(line)
  return tonumber(line:match("^## Line (%d+)") or line:match("^%s*|%s*(%d+)%s*|") or line:match("^%s*(%d+)"))
end

local function jump_to_response()
  local responses = DB.global_update().responses
  local win = vim.fn.bufwinid(get_current_response().buf)

  if CONFIG.get().default_view == "report" then
    local lnum = parse_report_line(vim.api.nvim_get_current_line())
    if not lnum then return end

    local current_name = get_current_response().name
    for i = #responses, 1, -1 do
      if
        responses[i].line == lnum and (not current_name or current_name == "" or responses[i].name == current_name)
      then
        set_current_response(i)
        break
      end
    end

    M.show_body()
  elseif win > 0 then
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { get_current_response().line, 0 })

    win = get_kulala_window()
    if vim.api.nvim_win_get_config(win).relative == "editor" then vim.api.nvim_win_close(win, true) end
  end
end

M.show_headers = function()
  local Markdown = require("kulala.ui.markdown")
  show(Markdown.format_headers_view(get_current_response()), "markdown", "headers")
end

M.show_body = function()
  local body, ft = format_body()
  show(body, ft, "body")
  if get_current_response().filter then M.toggle_filter() end
end

M.show_headers_body = function()
  local Markdown = require("kulala.ui.markdown")
  local r = get_current_response()
  local body, _ = format_body()
  show(Markdown.format_headers_body_view(r, body), "markdown", "headers_body")
end

M.show_verbose = function()
  local r = get_current_response()
  local Verbose = require("kulala.ui.verbose")
  local body = r._kulala_core and Verbose.format(r) or Verbose.format_legacy(r)
  show(body, "markdown", "verbose")
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
  local Markdown = require("kulala.ui.markdown")
  show(Markdown.format_script_output(get_current_response()), "markdown", "script_output")
end

M.show_report = function()
  show(REPORT.generate_requests_report(), "markdown", "report")
end

---Get the panes configured for the winbar and the index of the currently active pane based on the default view.
---@return table panes A list of pane names, current_index number index of the currently active pane
---@return number current_index of the currently active pane
local get_winbar_panes_and_current_index = function()
  local config = CONFIG.get()
  local panes = config.ui.default_winbar_panes
  local current_view = config.default_view
  local current_index
  for idx, pane in ipairs(panes) do
    if pane == current_view then current_index = idx end
  end

  return panes, current_index
end

M.show_previous_tab = function()
  local panes, current_index = get_winbar_panes_and_current_index()
  local previous_index = current_index > 1 and (current_index - 1) or #panes
  local previous_view = panes[previous_index]

  if previous_view then
    M["show_" .. previous_view]()
    CONFIG.options.default_view = previous_view
  end
end

M.show_next_tab = function()
  local panes, current_index = get_winbar_panes_and_current_index()
  local next_index = #panes > current_index and (current_index + 1) or 1
  local next_view = panes[next_index]

  if next_view then
    M["show_" .. next_view]()
    CONFIG.options.default_view = next_view
  end
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

M.show_news = function()
  local news = FS.get_plugin_root_dir() .. "/../../NEWS.md"
  local contents = FS.read_file(news) or "No news found"
  vim.cmd("lcd " .. vim.fs.dirname(news) .. "/docs/docs")

  show(contents, "markdown", "body")
  REPORT.hide_response_summary()

  local footer = vim.fn.bufnr("kulala://news_footer")
  if footer > -1 then vim.api.nvim_buf_delete(footer, { force = true }) end

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
    if open_view then open_view(get_current_response()) end
  end, debug.traceback)

  if not status then Logger.error("Errors displaying response: " .. (errors or ""), 1) end
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

  CMD.run_parser(nil, line_nr, function(success, duration, icon_linenr, response_id)
    if success then
      elapsed_ms = UI_utils.pretty_ms(duration)
      status = "done"
    else
      status = success == nil and "loading" or "error"
    end

    if not set_current_response_by_id(db, response_id) then
      local first_new = math.max(1, (db.previous_response_pos or 0) + 1)
      set_current_response(math.min(first_new, #db.responses))
    end

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
  local current = get_current_response()
  if current and current.method == "WS" then return require("kulala.cmd.websocket").close() end

  local acted = CMD.queue.interrupt_progressive()
  if not acted then return end

  INLAY.clear("kulala.loading")
  if #CMD.queue.tasks == 0 and CMD.queue.status ~= "running" then hide_progress() end
end

M.replay = function()
  local last_request = DB.global_find_unique("replay")
  if not last_request then return Logger.warn("No request to replay") end

  local run_opts = CMD.replay_run_opts(last_request)
  if not run_opts then
    return Logger.error("Cannot replay: missing HTTP file content for " .. (last_request.file or "unknown"))
  end

  local db = DB.global_update()
  local line = last_request.show_icon_line_number or last_request.start_line
  local buf = DB.get_current_buffer()
  local status, elapsed_ms

  db.previous_response_pos = #db.responses
  INLAY.clear()

  -- Re-parse the HTTP buffer and send full document content to kulala-core (all scripts, vars, KULALA_SHARED).
  CMD.run_parser(nil, line, function(success, duration, icon_linenr, response_id)
    if success then
      elapsed_ms = UI_utils.pretty_ms(duration)
      status = "done"
    else
      status = success == nil and "loading" or "error"
    end

    if not set_current_response_by_id(db, response_id) then set_current_response(#db.responses) end

    INLAY.show(buf, status, icon_linenr or INLAY.icon_line_for_request(last_request), elapsed_ms)
    M.open_default_view()

    return true
  end, run_opts)
end

M.close = function()
  M.close_kulala_buffer()

  local ext = vim.fn.expand("%:e")
  if ext == "http" or ext == "rest" then vim.api.nvim_buf_delete(vim.fn.bufnr(), {}) end
end

M.copy = function()
  local Bridge = require("kulala.cmd.kulala_core_bridge")

  if Bridge.enabled() then
    local curl, err = Bridge.to_curl_at_cursor(nil, GLOBALS.NAME .. "/" .. GLOBALS.VERSION)
    if curl then
      vim.fn.setreg("+", curl)
      Logger.info("Copied to clipboard")
      return
    end
    if err then
      if Bridge.is_preview_unsupported_err(err) then return Logger.warn(err) end
      Logger.warn(err .. " — falling back to legacy copy")
    end
  end

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
      local body_file_path = flag:sub(2)
      local body = FS.read_file(body_file_path, true) or "[could not read file]"

      local max_request_size = CONFIG.get().ui.max_request_size
      local body_size = vim.fn.getfsize(body_file_path)

      body = body_size > max_request_size and flag or body
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
  local Bridge = require("kulala.cmd.kulala_core_bridge")
  local lines, err = Bridge.from_curl(clipboard)
  if not lines then return Logger.error(err or "kulala-core from_curl failed") end
  vim.api.nvim_put(lines, "l", false, false)
end

M.inspect = function()
  local Bridge = require("kulala.cmd.kulala_core_bridge")
  local content, err = Bridge.inspect_request_at_cursor()
  if not content then
    if err and Bridge.is_preview_unsupported_err(err) then return Logger.warn(err) end
    return Logger.error(err or "kulala-core inspect_request failed")
  end

  if not content or #content == 0 then return end

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
