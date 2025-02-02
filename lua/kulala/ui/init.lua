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
local Logger = require("kulala.logger")
local AsciiUtils = require("kulala.utils.ascii")
local Inspect = require("kulala.parser.inspect")

local M = {}

local function get_kulala_buffer()
  local buf = vim.fn.bufnr(GLOBALS.UI_ID)
  return buf > 0 and buf or nil
end

local function get_kulala_window()
  local win = vim.fn.bufwinid(get_kulala_buffer())
  return win > 0 and win or nil
end

local open_float = function()
  local bufnr = vim.api.nvim_create_buf(false, false) --FIX: listed, scratch false?
  vim.api.nvim_buf_set_name(bufnr, GLOBALS.UI_ID)

  local width = math.max(vim.api.nvim_win_get_width(0) - 10, 1)
  local height = math.max(vim.api.nvim_win_get_height(0) - 10, 1)

  vim.api.nvim_open_win(bufnr, true, {
    title = "Kulala",
    title_pos = "center",
    relative = "editor",
    border = "single",
    width = width,
    height = height,
    row = math.floor(((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
  })
end

---This makes sure to replace the buffer with a new one
---This is necessary to prevent bugs like this:
-- https://github.com/mistweaverco/kulala.nvim/issues/128
local replace_buffer = function()
  local config = CONFIG.get()
  local callbacks = UICallbacks.get("on_replace_buffer")
  -- local old_bufnr = get_buffer()
  local buf = get_kulala_buffer()

  -- local new_bufnr = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].buftype = "nofile"

  -- if old_bufnr ~= nil then
  -- for _, win in ipairs(vim.fn.win_findbuf(old_bufnr)) do
  --   vim.api.nvim_win_set_buf(win, new_bufnr)
  -- end

  --   vim.api.nvim_buf_delete(old_bufnr, { force = true })
  --   vim.api.nvim_buf_set_name(new_bufnr, GLOBALS.UI_ID)
  -- end

  -- Set the buffer name to the UI_ID after we have deleted the old buffer

  for _, callback in ipairs(callbacks) do
    callback(_, buf)
  end

  if config.display_mode == "float" and config.q_to_close_float then
    vim.api.nvim_buf_set_keymap(buf, "n", "q", ":bd<CR>", { noremap = true, silent = true })
  end

  return buf
end

local open_split = function()
  local sd = CONFIG.get().split_direction == "vertical" and "vsplit" or "split"
  local prev_win = vim.api.nvim_get_current_win()

  vim.cmd("keepalt " .. sd .. " " .. GLOBALS.UI_ID)

  WINBAR.create_winbar(get_kulala_window())
  vim.api.nvim_set_current_win(prev_win)
end

local open_buffer = function()
  if get_kulala_buffer() then
    return
  end

  return CONFIG.get().display_mode == "split" and open_split() or open_float()
end

local close_buffer = function()
  vim.cmd("bdelete! " .. GLOBALS.UI_ID)
end

-- Create an autocmd to delete the buffer when the window is closed
-- This is necessary to prevent the buffer from being left behind
-- when the window is closed
local augroup = vim.api.nvim_create_augroup("kulala_window_closed", { clear = true })

vim.api.nvim_create_autocmd("WinClosed", {
  group = augroup,
  callback = function(args)
    -- if the window path is the same as the GLOBALS.UI_ID and the buffer exists
    local buf = get_kulala_buffer()
    if buf and args.buf == buf then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end,
})

local function set_buffer_contents(contents, ft)
  if not get_kulala_buffer() then
    return
  end

  local buf = replace_buffer()
  local filetype
  -- local buf = get_kulala_buffer()
  -- setup filetype first so that treesitter foldexpr can calculate fold level per lines
  filetype = ft ~= nil and ft or "text"
  vim.bo[buf].filetype = filetype

  local lines = vim.split(contents, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- setup filetype second to trigger filetype autocmd
  -- first setup's filetype buffer is empty
  filetype = ft ~= nil and ft or "text"
  vim.bo[buf].filetype = filetype
end

local function pretty_ms(ms)
  return string.format("%.2fms", ms)
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

M.copy = function()
  local result = PARSER.parse()
  if result == nil then
    Logger.error("No request found")
    return
  end
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
  local spec, curl = CURL_PARSER.parse(clipboard)
  if spec == nil then
    Logger.error("Failed to parse curl command")
    return
  end
  -- put the curl command in the buffer as comment
  print_http_spec(spec, curl)
end

M.open_default_view = function()
  local default_view = CONFIG.get().default_view
  open_buffer()

  local open_view = M["show_" .. default_view]
  _ = open_view and open_view()
end

M.open = function()
  DB.current_buffer = vim.fn.bufnr()
  INLAY.clear()

  vim.schedule(function()
    local variables, requests = PARSER.get_document()
    local req = PARSER.get_request_at(requests)

    if req == nil then
      Logger.error("No request found")
      return
    end

    if req.show_icon_line_number then
      INLAY:show_loading(req.show_icon_line_number)
    end

    CMD.run_parser(requests, req, variables, function(success, start)
      if not success then
        if req.show_icon_line_number then
          INLAY:show_error(req.show_icon_line_number)
        end
        return
      else
        local elapsed = vim.loop.hrtime() - start
        local elapsed_ms = pretty_ms(elapsed / 1e6)
        INLAY:show_done(req.show_icon_line_number, elapsed_ms)

        M.open_default_view()
      end

      return true
    end)
  end)
end

M.open_all = function()
  DB.current_buffer = vim.fn.bufnr()
  INLAY.clear()

  local variables, requests = PARSER.get_document()

  if not requests then
    return Logger.error("No requests found in the document")
  end

  CMD.run_parser(requests, nil, variables, function(success, start, icon_linenr)
    if not success then
      INLAY:show_error(icon_linenr)
      return
    else
      local elapsed = vim.loop.hrtime() - start
      local elapsed_ms = pretty_ms(elapsed / 1e6)

      INLAY:show_done(icon_linenr, elapsed_ms)
      M.open_default_view()
    end

    return true
  end)
end

M.close = function()
  close_buffer()
  local ext = vim.fn.expand("%:e")
  if ext == "http" or ext == "rest" then
    vim.cmd("bdelete")
  end
end

local function format_body(body)
  local contenttype = INT_PROCESSING.get_config_contenttype()
  local filetype

  if contenttype.formatter then
    body = FORMATTER.format(contenttype.formatter, body)
    filetype = contenttype.ft
  end

  return body, filetype
end

local function show(contents, filetype, mode)
  open_buffer()
  set_buffer_contents(contents, filetype)

  WINBAR.toggle_winbar_tab(get_kulala_window(), mode)
  CONFIG.options.default_view = mode
end

M.show_headers = function()
  local headers = FS.read_file(GLOBALS.HEADERS_FILE)

  if not headers then
    return Logger.warn("No headers found")
  end

  headers = headers:gsub("\r\n", "\n")
  show(headers, "text", "headers_body")
end

M.show_body = function()
  local body = FS.read_file(GLOBALS.BODY_FILE)
  local filetype

  if not body then
    return Logger.warn("No body found")
  end

  body, filetype = format_body(body)
  show(body, filetype, "body")
end

M.show_headers_body = function()
  local headers = FS.read_file(GLOBALS.HEADERS_FILE)
  local body = FS.read_file(GLOBALS.BODY_FILE)
  local filetype

  if not headers or not body then
    return Logger.warn("No headers or body found")
  end

  body, filetype = format_body(body)
  headers = headers:gsub("\r\n", "\n") .. "\n"

  show(headers .. body, filetype, "headers_body")
end

M.show_verbose = function()
  local body = FS.read_file(GLOBALS.BODY_FILE)
  local errors = FS.read_file(GLOBALS.ERRORS_FILE)
  local filetype = "kulala_verbose_result"

  if not body then
    return Logger.warn("No body found")
  end

  body = format_body(body)
  errors = errors and errors:gsub("\r", "") .. "\n" or ""

  show(errors .. body, filetype, "verbose")
end

M.show_stats = function()
  local stats = FS.read_file(GLOBALS.STATS_FILE)
  local filetype = "text"

  if not stats then
    return Logger.warn("No body found")
  end

  stats = vim.json.decode(stats)

  local diagram_lines = AsciiUtils.get_waterfall_timings(stats)
  local diagram = table.concat(diagram_lines, "\n")

  show(diagram, filetype, "stats")
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
    open_buffer()
    local contents = ""
    if pre_file_contents ~= nil then
      contents = contents .. M.generate_ascii_header("Pre Script") .. "\n" .. pre_file_contents:gsub("\r\n", "\n")
    end
    if post_file_contents ~= nil then
      contents = contents .. M.generate_ascii_header("Post Script") .. "\n" .. post_file_contents:gsub("\r\n", "\n")
    end
    set_buffer_contents(contents, "text")
    if CONFIG.get().winbar then
      WINBAR.toggle_winbar_tab(get_kulala_window(), "script_output")
    end
    CONFIG.options.default_view = "script_output"
  else
    Logger.error("No script output found")
  end
end

M.replay = function()
  local result = DB.global_find_unique("replay")
  if result == nil then
    vim.notify("No request to replay", vim.log.levels.WARN, { title = "kulala" })
    return
  end
  vim.schedule(function()
    local variables, requests = PARSER.get_document()
    CMD.run_parser(requests, result, variables, function(success)
      if not success then
        vim.notify("Failed to replay request", vim.log.levels.ERROR, { title = "kulala" })
        return
      else
        M.open_default_view()
      end
    end)
  end)
end

M.scratchpad = function()
  vim.cmd("e " .. GLOBALS.SCRATCHPAD_ID)
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
