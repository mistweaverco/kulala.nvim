local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")
local Keymaps = require("kulala.config.keymaps")
local Logger = require("kulala.logger")

local M = {}

M.connection = nil
M.response = nil

local function parse_ws_line(data)
  if not data or data == "" then return nil end
  local ok, msg = pcall(vim.json.decode, data)
  if ok and type(msg) == "table" then return msg end
  return nil
end

---Persist live WebSocket body so `save_response` and the UI read the current stream.
local function persist_response_body()
  if not M.response then return end
  FS.write_file(GLOBALS.BODY_FILE, M.response.body or "")
end

---@param callback function
---@param success boolean
local function notify_ui(callback, success)
  persist_response_body()
  callback(success, 0, M.response and M.response.line or 0)
end

M.on_stdout = function(_, data, callback)
  if not data or #data == 0 then return end

  for line in data:gmatch("[^\n]+") do
    local msg = parse_ws_line(line)
    if msg and msg.type == "message" and msg.data then
      M.response.body = M.response.body .. ("\n=> " .. msg.data)
      notify_ui(callback, true)
    elseif msg and msg.type == "closed" then
      M.response.status = false
      M.response.code = -1
      M.response.body = M.response.body:gsub("^.-\n.-\n", "Connection closed\n")
      notify_ui(callback, false)
    elseif msg and msg.type == "error" then
      Logger.error("Error connecting to WS: " .. (msg.error or ""))
    end
  end
end

M.on_stderr = function(_, data, callback)
  if not data or #data == 0 then return end
  Logger.error("Error connecting to WS: " .. data)

  M.response.code = -1
  M.response.status = false

  M.response.body = M.response.body:gsub("^.-\n.-\n", "Connection closed\n")
  M.response.errors = M.response.errors .. "\n" .. data

  notify_ui(callback, false)
end

M.on_exit = function(system, _, callback)
  M.response.code = system.code == 0 and -1 or system.code
  M.response.status = false

  M.response.body = M.response.body:gsub("^.-\n.-\n", "Connection closed\n")

  notify_ui(callback, false)
end

local function set_welcome_message()
  local keymaps = Keymaps.get_kulala_keymaps() or {}
  local send_key = keymaps["Jump to response"][1] .. "\\" .. keymaps["Send WS message"][1]
  local close_key = keymaps["Interrupt requests"][1]

  M.response.body = ("Connected... Waiting for data.\nPress %s to send message and %s to close connection.\n\n"):format(
    send_key,
    close_key
  ) .. M.response.body
end

function M.connect(request, response, callback, opts)
  opts = opts or {}
  response.body = ""

  if M.connection then M.close() end

  local _, core_cwd = KULALA_CORE.resolve_document_paths(0, request.file)

  local function handler(event)
    return function(system, data)
      vim.schedule(function()
        if event == "on_stdout" and data then
          for line in data:gmatch("[^\n]+") do
            local msg = parse_ws_line(line)
            if msg and msg.type == "ready" then
              set_welcome_message()
              notify_ui(callback, true)
            end
          end
        end
        local call = opts[event] or M[event]
        call(system, data, callback)
      end)
    end
  end

  local status, result = xpcall(function()
    return KULALA_CORE.websocket_start({
      url = request.url,
      body = request.body_computed or request.body,
      headers = request.headers,
    }, {
      on_stdout = handler("on_stdout"),
      on_stderr = handler("on_stderr"),
      on_exit = handler("on_exit"),
    }, core_cwd)
  end, debug.traceback)

  if not status then return Logger.error("Failed to connect to websocket:\n" .. result, 2) end
  if not result then return Logger.error("kulala-core WebSocket failed to start", 2) end

  M.connection = result
  M.response = response

  return result.pid
end

local function get_selection()
  local mode = vim.api.nvim_get_mode().mode
  local lines

  if mode == "V" or mode == "v" then
    vim.api.nvim_input("<Esc>")
    local v_start, v_end = vim.fn.getpos("."), vim.fn.getpos("v")
    lines = vim.fn.getregion(v_start, v_end, { type = mode })
  else
    lines = { vim.fn.getline(".") }
  end

  return lines
end

function M.send(data)
  local conn = M.connection
  if not conn or conn:is_closing() then return false end

  data = data and data:gsub("\n$", "")
  data = data and { data } or get_selection()

  vim.iter(data):each(function(line)
    conn:write(vim.json.encode { op = "send", data = line } .. "\n")
  end)

  return true
end

function M.close()
  local conn = M.connection
  if not conn then return false end

  if not conn:is_closing() then
    conn:write(vim.json.encode { op = "close" } .. "\n")
    vim.wait(500, function()
      return conn:is_closing()
    end)
    if not conn:is_closing() then conn:kill(15) end
  end
  M.connection = nil

  return true
end

function M.is_active()
  local conn = M.connection
  return conn and not conn:is_closing()
end

return M
