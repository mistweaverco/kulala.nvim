local Backend = require("kulala.backend")
local CONFIG = require("kulala.config")

local M = {}

---@type vim.SystemObj|nil
M.active_job = nil

---User-configured path from setup (`kulala_core.path`), if any.
---@return string|nil
local function configured_core_path()
  local p = CONFIG.get().kulala_core.path
  if type(p) == "string" and vim.trim(p) ~= "" then return vim.trim(p) end
  return nil
end

---Resolve kulala-core executable: explicit `kulala_core.path` wins;
---otherwise default download location
---from `Backend.get_bin_path()`, if executable.
---Returns nil if not found or not executable.
---@return string|nil
function M.executable_path()
  local configured = configured_core_path()
  if configured then
    if vim.fn.executable(configured) == 1 then return vim.fn.exepath(configured) end
    return nil
  end
  if vim.fn.executable(Backend.get_bin_path()) == 1 then return vim.fn.exepath(Backend.get_bin_path()) end
  return nil
end

function M.enabled()
  return M.executable_path() ~= nil
end

function M.require_enabled()
  local exe = M.executable_path()
  if exe then return exe end

  local configured = configured_core_path()
  if configured then error(("kulala_core.path is not executable: %s"):format(configured), 0) end
  error(
    "kulala-core not found. "
      .. "Either let kulala.nvim auto-download and install kulala-core or set `kulala_core.path` in setup.",
    0
  )
end

---Matches `packages/core/src/lib/runner/external-tools/paths.ts` (`getKulalaCoreDataDir`).
---@return string
local function default_kulala_core_data_dir()
  local explicit = vim.fn.getenv("KULALA_CORE_DATA_DIR")
  if type(explicit) == "string" and explicit ~= "" then return explicit end

  local sysname = (vim.uv.os_uname() or {}).sysname or ""
  if sysname == "Windows_NT" or vim.fn.has("win32") == 1 then
    local la = vim.fn.getenv("LOCALAPPDATA")
    if type(la) == "string" and la ~= "" then return la:gsub("\\", "/") .. "/kulala-core" end
    return vim.fn.expand("~/kulala-core")
  end

  if sysname == "Darwin" then return vim.fn.expand("~/Library/Application Support/kulala-core") end

  local xdg = vim.fn.getenv("XDG_DATA_HOME")
  if type(xdg) == "string" and xdg ~= "" then return xdg .. "/kulala-core" end

  return vim.fn.expand("~/.local/share/kulala-core")
end

---@return string
function M.effective_data_dir()
  local dir = CONFIG.get().kulala_core.data_dir
  if type(dir) == "string" and dir ~= "" then return dir end
  return default_kulala_core_data_dir()
end

local function env_with_data_dir()
  local env = vim.fn.environ()
  env.KULALA_CORE_DATA_DIR = M.effective_data_dir()
  return env
end

---Subprocess timeout (ms). Uses `kulala_core.timeout`, else 1 minute.
---@return number|nil nil disables vim.system timeout (not recommended)
local function invoke_timeout_ms()
  local t = CONFIG.get().kulala_core.timeout
  if t == nil then return 60000 end
  if type(t) == "number" and t > 0 then return t end
  return nil
end

---@param bufnr integer
---@param explicit_path string|nil
---@return string|nil filepath
---@return string cwd
---@return string display_path
function M.resolve_document_paths(bufnr, explicit_path)
  bufnr = bufnr or 0
  local candidates = {}

  local function push(p)
    if type(p) ~= "string" or p == "" then return end
    local abs = vim.fn.fnamemodify(p, ":p")
    if abs == "" then return end
    for _, c in ipairs(candidates) do
      if c == abs then return end
    end
    table.insert(candidates, abs)
  end

  push(explicit_path)
  push(vim.api.nvim_buf_get_name(bufnr))

  local filepath_core = nil
  for _, abs in ipairs(candidates) do
    if vim.fn.filereadable(abs) == 1 then
      local norm = (vim.fs and vim.fs.normalize(abs)) or abs
      filepath_core = (vim.loop.fs_realpath(norm)) or norm
      break
    end
  end

  local cwd = nil
  if filepath_core then
    local d = vim.fn.fnamemodify(filepath_core, ":h")
    if vim.fn.isdirectory(d) == 1 then cwd = d end
  end
  if not cwd and #candidates > 0 then
    local d = vim.fn.fnamemodify(candidates[1], ":h")
    if vim.fn.isdirectory(d) == 1 then cwd = d end
  end
  if not cwd then
    local n = vim.api.nvim_buf_get_name(bufnr)
    if type(n) == "string" and n ~= "" then
      local d = vim.fn.fnamemodify(n, ":p:h")
      if vim.fn.isdirectory(d) == 1 then cwd = d end
    end
  end
  if not cwd then cwd = vim.loop.cwd() end

  local display = filepath_core or candidates[1] or ""
  return filepath_core, cwd, display
end

---@param raw string|nil
---@return table|nil doc
local function decode_document_json(raw)
  if type(raw) ~= "string" then return nil end
  local trimmed = vim.trim(raw)
  if trimmed == "" then return nil end
  local ok, doc = pcall(vim.json.decode, trimmed)
  if ok and type(doc) == "table" and type(doc.blocks) == "table" then return doc end
  return nil
end

---@param stdout string|nil
---@return table|nil
function M.try_decode_wrapper(stdout)
  local raw = vim.trim(stdout or "")
  if raw == "" then return nil end
  local ok, w = pcall(vim.json.decode, raw)
  if ok and type(w) == "table" and w.type then return w end
  return nil
end

---Stop the in-flight kulala-core subprocess (e.g. Ctrl+C interrupt).
---@return boolean stopped
function M.interrupt_active()
  local job = M.active_job
  if not job then return false end
  M.active_job = nil
  pcall(function()
    job:kill("sigterm")
  end)
  return true
end

---@param payload table
---@param cwd string|nil
---@param on_done fun(job: vim.SystemCompleted)
function M.invoke_async(payload, cwd, on_done)
  local exe = M.require_enabled()
  local opts = {
    stdin = vim.json.encode(payload) .. "\n",
    text = true,
    env = env_with_data_dir(),
  }
  local timeout_ms = invoke_timeout_ms()
  if timeout_ms then opts.timeout = timeout_ms end
  if type(cwd) == "string" and cwd ~= "" and vim.fn.isdirectory(cwd) == 1 then opts.cwd = cwd end

  M.active_job = vim.system({ exe }, opts, function(job)
    if M.active_job == job then M.active_job = nil end
    on_done(job)
  end)
end

---@param payload table
---@param cwd string|nil
---@return vim.SystemCompleted
function M.invoke(payload, cwd)
  local done = false
  local completed ---@type vim.SystemCompleted
  M.invoke_async(payload, cwd, function(job)
    completed = job
    done = true
  end)
  vim.wait(invoke_timeout_ms() or 600000, function()
    return done
  end, 20)
  return completed or { code = 124, stdout = "", stderr = "kulala-core subprocess timed out" }
end

---@param first table|nil
---@return boolean
local function is_prompt_item(first)
  if type(first) ~= "table" then return false end
  if first.prompt == true then return true end
  if
    type(first.promptId) == "string"
    and first.promptId ~= ""
    and type(first.promptType) == "string"
    and first.promptType ~= ""
  then
    return true
  end
  return false
end

---@param job vim.SystemCompleted
---@return table|nil catalog
---@return string|nil err
local function catalog_from_job(job)
  local raw = vim.trim(job.stdout or "")
  if raw == "" then
    return nil, vim.trim(job.stderr or "") ~= "" and vim.trim(job.stderr) or "kulala-core environments failed"
  end
  local ok, catalog = pcall(vim.json.decode, raw)
  if ok and type(catalog) == "table" and type(catalog.environments) == "table" then return catalog, nil end
  if job.code ~= 0 then
    return nil, vim.trim(job.stderr or "") ~= "" and vim.trim(job.stderr) or "kulala-core environments failed"
  end
  return nil, "invalid kulala-core environments output"
end

---@param cwd string|nil
---@return table|nil catalog `{ environments, $shared? }`
---@return string|nil err
function M.list_environments(cwd)
  M.require_enabled()
  cwd = cwd or vim.loop.cwd()
  local payload = { action = "environments", cwd = cwd }
  local job = M.invoke(payload, cwd)
  return catalog_from_job(job)
end

---@param cwd string|nil
---@param on_done fun(catalog: table|nil, err: string|nil)
function M.list_environments_async(cwd, on_done)
  if not M.enabled() then
    vim.schedule(function()
      on_done(nil, "kulala-core not found")
    end)
    return
  end
  cwd = cwd or vim.loop.cwd()
  local payload = { action = "environments", cwd = cwd }
  M.invoke_async(payload, cwd, function(job)
    vim.schedule(function()
      on_done(catalog_from_job(job))
    end)
  end)
end

function M.parse_document(content, filepath, cwd_override)
  M.require_enabled()
  local cwd = cwd_override
  if not cwd and type(filepath) == "string" and filepath ~= "" then
    local d = vim.fn.fnamemodify(filepath, ":h")
    if vim.fn.isdirectory(d) == 1 then cwd = d end
  end
  local payload = { action = "parse", content = content }
  if type(filepath) == "string" and filepath ~= "" then payload.filepath = filepath end
  local job = M.invoke(payload, cwd)

  local doc = decode_document_json(job.stdout) or decode_document_json(job.stderr)
  if doc then return doc, nil end

  if job.code ~= 0 then
    return nil, vim.trim(job.stderr or "") ~= "" and vim.trim(job.stderr) or "kulala-core parse failed"
  end
  return nil, "invalid kulala-core parse output"
end

---@param job vim.SystemCompleted
---@return table|nil wrapper
---@return string|nil err
local function run_result_from_job(job)
  local wrapper = M.try_decode_wrapper(job.stdout)
  local first = wrapper and wrapper.data and wrapper.data[1]
  local is_prompt = wrapper and wrapper.type == "responses" and is_prompt_item(first)

  if job.code ~= 0 and not is_prompt then
    local err = vim.trim(job.stderr or "")
    if err == "" then
      if job.code == 124 or job.code == -1 then
        err = "kulala-core subprocess timed out"
      else
        err = "kulala-core run failed (exit " .. tostring(job.code) .. ")"
      end
    end
    return nil, err
  end

  if not wrapper or type(wrapper) ~= "table" then return nil, "invalid kulala-core run output" end
  return wrapper, nil
end

function M.run(payload, cwd)
  M.require_enabled()
  payload.action = "run"
  local job = M.invoke(payload, cwd)
  return run_result_from_job(job)
end

---Non-blocking run; calls `on_done(wrapper, err)` on the main loop when finished.
---@param payload table
---@param cwd string|nil
---@param on_done fun(wrapper: table|nil, err: string|nil)
function M.run_async(payload, cwd, on_done)
  M.require_enabled()
  payload.action = "run"
  M.invoke_async(payload, cwd, function(job)
    local wrapper, err = run_result_from_job(job)
    on_done(wrapper, err)
  end)
end

---@param job vim.SystemCompleted
---@return table|nil wrapper
---@return string|nil err
local function continue_result_from_job(job)
  local wrapper = M.try_decode_wrapper(job.stdout)
  if wrapper then return wrapper, nil end
  if job.code ~= 0 then
    local err = vim.trim(job.stderr or "")
    if err == "" then err = "kulala-core continue failed (exit " .. tostring(job.code) .. ")" end
    return nil, err
  end
  return nil, "invalid kulala-core continue output"
end

function M.continue(payload, cwd)
  M.require_enabled()
  payload.action = "continue"
  local job = M.invoke(payload, cwd)
  return continue_result_from_job(job)
end

---@param payload table
---@param cwd string|nil
---@param on_done fun(wrapper: table|nil, err: string|nil)
function M.continue_async(payload, cwd, on_done)
  M.require_enabled()
  payload.action = "continue"
  M.invoke_async(payload, cwd, function(job)
    local wrapper, err = continue_result_from_job(job)
    on_done(wrapper, err)
  end)
end

---@param stdout string|nil
---@return table|nil
local function decode_action_response(stdout)
  local raw = vim.trim(stdout or "")
  if raw == "" then return nil end
  local ok, res = pcall(vim.json.decode, raw)
  if ok and type(res) == "table" then return res end
  return nil
end

---@param key_or_keys string|string[]|nil nil clears all global script variables
---@return boolean ok
---@return string|nil err
function M.clear_globals(key_or_keys)
  M.require_enabled()
  local names = nil
  if type(key_or_keys) == "string" then
    names = { key_or_keys }
  elseif type(key_or_keys) == "table" then
    names = key_or_keys
  end
  local payload = { action = "clear_globals" }
  if names then payload.names = names end
  local job = M.invoke(payload, nil)
  local res = decode_action_response(job.stdout)
  if res and res.success == true then return true, nil end
  if res and res.error then return false, res.error end
  if job.code ~= 0 then
    return false, vim.trim(job.stderr or "") ~= "" and vim.trim(job.stderr) or "kulala-core clear_globals failed"
  end
  return false, "invalid kulala-core clear_globals output"
end

---@param op string
---@param args table|nil
---@param cwd string|nil
---@return string|nil value
---@return string|nil err
function M.crypto(op, args, cwd)
  M.require_enabled()
  local payload = vim.tbl_extend("force", { action = "crypto", op = op }, args or {})
  local job = M.invoke(payload, cwd)
  local res = decode_action_response(job.stdout)
  if res and res.success == true and res.value ~= nil then return tostring(res.value), nil end
  if res and res.error then return nil, res.error end
  if job.code ~= 0 then
    return nil, vim.trim(job.stderr or "") ~= "" and vim.trim(job.stderr) or "kulala-core crypto failed"
  end
  return nil, "invalid kulala-core crypto output"
end

---@param opts {
---   url: string,
---   method?: string,
---   headers?: table,
---   body?: string,
---   insecure?: boolean,
---   timeoutSec?: number,
---   connectionTimeoutSec?: number,
--- }
---@param cwd string|nil
---@return table|nil result { status, headers, body, url }
---@return string|nil err
function M.http_request(opts, cwd)
  M.require_enabled()
  local payload = vim.tbl_extend("force", {
    action = "http_request",
    url = opts.url,
    method = opts.method or "GET",
    headers = opts.headers or {},
    body = opts.body,
    insecure = opts.insecure,
    timeoutSec = opts.timeoutSec,
    connectionTimeoutSec = opts.connectionTimeoutSec,
  }, {})
  local job = M.invoke(payload, cwd)
  local res = decode_action_response(job.stdout)
  if res and res.success == true then
    return {
      status = res.status,
      headers = res.headers or {},
      body = res.body or "",
      url = res.url or opts.url,
    },
      nil
  end
  if res and res.error then return nil, res.error end
  if job.code ~= 0 then
    return nil, vim.trim(job.stderr or "") ~= "" and vim.trim(job.stderr) or "kulala-core http_request failed"
  end
  return nil, "invalid kulala-core http_request output"
end

---Start a long-lived WebSocket session (native kulala-core, replaces websocat).
---@param opts { url: string, body?: string, headers?: table }
---@param handlers { on_stdout: function, on_stderr: function, on_exit: function }
---@param cwd string|nil
---@return vim.SystemObj|nil
function M.websocket_start(opts, handlers, cwd)
  M.require_enabled()
  local exe = M.executable_path()
  if not exe then return nil end

  local tmp = vim.fn.tempname() .. ".json"
  local payload = {
    url = opts.url,
    body = opts.body,
    headers = opts.headers,
  }
  vim.fn.writefile({ vim.json.encode(payload) }, tmp)

  return vim.system({ exe, "--websocket", "-i", tmp }, {
    stdin = true,
    text = true,
    cwd = cwd,
    env = env_with_data_dir(),
    stdout = handlers.on_stdout,
    stderr = handlers.on_stderr,
  }, handlers.on_exit)
end

return M
