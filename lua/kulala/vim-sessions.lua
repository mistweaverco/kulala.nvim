local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local GLOBALS = require("kulala.globals")

local M = {}

local api = vim.api

-- From :h 'sessionoptions', only globals starting with an uppercase letter
-- (and containing at least a single lowercase letter) are restored.
local SESSION_VARIABLES = {
  global_data = "KulalaGlobalData",
  default_view = "KulalaDefaultView",
  display_mode = "KulalaDisplayMode",
  selected_env = "KulalaSelectedEnv",
}

local VALID_VIEWS = {
  body = true,
  headers = true,
  headers_body = true,
  verbose = true,
  report = true,
}

local VALID_DISPLAY_MODES = {
  split = true,
  float = true,
}

local KULALA_BUFFER_PATTERNS = {
  "^" .. vim.pesc(GLOBALS.UI_ID) .. "$",
  "^" .. vim.pesc(GLOBALS.SCRATCHPAD_ID) .. "$",
  "^kulala://",
  "^kulala_help$",
}

local function is_kulala_buffer(buf)
  local name = api.nvim_buf_get_name(buf)
  for _, pattern in ipairs(KULALA_BUFFER_PATTERNS) do
    if name:match(pattern) then return true end
  end

  local ft = vim.bo[buf].filetype
  return ft == "kulala_ui" or ft == "kulala_ws_input"
end

local function serialize_global_data(global_data)
  local copy = vim.deepcopy(global_data)
  for _, resp in ipairs(copy.responses or {}) do
    resp.buf = nil
  end
  return vim.json.encode(copy)
end

local function remap_response_bufs(responses)
  for _, resp in ipairs(responses or {}) do
    local buf = -1
    if type(resp.buf_name) == "string" and resp.buf_name ~= "" then buf = vim.fn.bufnr(resp.buf_name, true) end
    if buf < 1 and type(resp.file) == "string" and resp.file ~= "" then buf = vim.fn.bufnr(resp.file, true) end
    resp.buf = buf > 0 and buf or nil
  end
end

local function set_current_buffer_from_history()
  local gd = DB.global_data
  local pos = gd.current_response_pos
  if pos > 0 and gd.responses[pos] and gd.responses[pos].buf then
    DB.current_buffer = gd.responses[pos].buf
    return
  end

  for i = #gd.responses, 1, -1 do
    local buf = gd.responses[i].buf
    if buf and api.nvim_buf_is_valid(buf) then
      DB.current_buffer = buf
      return
    end
  end
end

M.save_state = function()
  if not CONFIG.get().session.restore then return end

  vim.g[SESSION_VARIABLES.global_data] = serialize_global_data(DB.global_data)

  local default_view = CONFIG.get().default_view
  if type(default_view) == "string" then
    vim.g[SESSION_VARIABLES.default_view] = default_view
  else
    vim.g[SESSION_VARIABLES.default_view] = nil
  end

  vim.g[SESSION_VARIABLES.display_mode] = CONFIG.get().display_mode

  local selected_env = vim.g.kulala_selected_env or DB.find_unique("selected_env")
  vim.g[SESSION_VARIABLES.selected_env] = selected_env
end

M.restore_state = function()
  if not CONFIG.get().session.restore then return end

  local raw = vim.g[SESSION_VARIABLES.global_data]
  if type(raw) == "string" and raw ~= "" then
    local global_data = vim.json.decode(raw) or {}
    DB.global_data = {
      responses = global_data.responses or {},
      current_response_pos = global_data.current_response_pos or 0,
      previous_response_pos = global_data.previous_response_pos or 0,
      replay = global_data.replay,
    }
    remap_response_bufs(DB.global_data.responses)
    set_current_buffer_from_history()
  end

  local default_view = vim.g[SESSION_VARIABLES.default_view]
  if type(default_view) == "string" and VALID_VIEWS[default_view] then CONFIG.options.default_view = default_view end

  local display_mode = vim.g[SESSION_VARIABLES.display_mode]
  if type(display_mode) == "string" and VALID_DISPLAY_MODES[display_mode] then
    CONFIG.options.display_mode = display_mode
  end

  local selected_env = vim.g[SESSION_VARIABLES.selected_env]
  if type(selected_env) == "string" and selected_env ~= "" then
    vim.g.kulala_selected_env = selected_env
    if DB.data then DB.data.selected_env = selected_env end
  end
end

M.load_session_hook = function()
  if not CONFIG.get().session.restore then return end

  local had_kulala_bufs = false

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if is_kulala_buffer(buf) then
      had_kulala_bufs = true
      api.nvim_buf_delete(buf, { force = true })
    end
  end

  local has_saved_state = type(vim.g[SESSION_VARIABLES.global_data]) == "string"
    and vim.g[SESSION_VARIABLES.global_data] ~= ""

  if not (had_kulala_bufs or has_saved_state) then return end

  M.restore_state()

  if had_kulala_bufs and #DB.global_data.responses > 0 then
    vim.schedule(function()
      require("kulala.ui").open_default_view()
    end)
  end
end

M.setup = function()
  local augroup = api.nvim_create_augroup("kulala_vim_sessions", { clear = true })

  api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = M.save_state,
  })

  api.nvim_create_autocmd("SessionLoadPost", {
    group = augroup,
    callback = M.load_session_hook,
  })

  -- Lazy-loaded plugins can miss SessionLoadPost; vim.v.this_session is set while loading.
  if vim.v.this_session and vim.v.this_session ~= "" then vim.schedule(M.load_session_hook) end
end

return M
