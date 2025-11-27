local Config = require("kulala.config")
local Keymaps = require("kulala.config.keymaps")
local Logger = require("kulala.logger")

local M = {}

M.connection = nil
M.response = nil

M.on_stdout = function(_, data, callback)
  if not data or #data == 0 then return end

  data = "\n=> " .. data
  M.response.body = M.response.body .. data

  callback(true, 0, M.response.line)
end

M.on_stderr = function(_, data, callback)
  if not data or #data == 0 then return end
  Logger.error("Error connecting to WS: " .. data)

  M.response.code = -1
  M.response.status = false

  M.response.body = M.response.body:gsub("^.-\n.-\n", "Connection closed\n")
  M.response.errors = M.response.errors .. "\n" .. data

  callback(false, 0, M.response.line)
end

M.on_exit = function(system, _, callback)
  M.response.code = system.code == 0 and -1 or system.code
  M.response.status = false

  M.response.body = M.response.body:gsub("^.-\n.-\n", "Connection closed\n")

  callback(M.response.status, 0, M.response.line)
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
  local ws_cmd = Config.get().websocat_path
  if vim.fn.executable(ws_cmd) == 0 then return Logger.error("Websocat command not found: " .. ws_cmd, 2) end

  opts = opts or {}
  response.body = ""

  _ = M.connection and M.close()

  local function handler(event)
    return function(system, data)
      vim.schedule(function()
        local call = opts[event] or M[event]
        call(system, data, callback)
      end)
    end
  end

  local status, result = xpcall(function()
    return vim.system({ ws_cmd, request.url }, {
      stdin = true,
      text = true,
      stdout = handler("on_stdout"),
      stderr = handler("on_stderr"),
    }, handler("on_exit"))
  end, debug.traceback)

  if not status then return Logger.error("Failed to connect to websocket:\n" .. result, 2) end

  M.connection = result
  M.response = response

  _ = #request.body_computed > 0 and M.send(request.body_computed)
  set_welcome_message()

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

local function update_response()
  local ui_buf = require("kulala.ui").get_kulala_buffer()
  local lines = ui_buf and vim.api.nvim_buf_get_lines(ui_buf, 4, -1, false) or {}

  M.response.body = table.concat(lines, "\n")
end

function M.send(data)
  local conn = M.connection
  if not conn or conn:is_closing() then return false end

  data = data and data:gsub("\n$", "")
  data = data and { data } or get_selection()

  update_response()

  vim.iter(data):each(function(line)
    conn:write(line .. "\n")
  end)

  return true
end

function M.close()
  local conn = M.connection
  if not conn then return false end

  _ = not conn:is_closing() and conn:kill(15) -- SIGTERM
  M.connection = nil

  return true
end

function M.is_active()
  local conn = M.connection
  return conn and not conn:is_closing()
end

return M
