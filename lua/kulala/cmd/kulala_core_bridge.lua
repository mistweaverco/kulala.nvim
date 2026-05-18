local CONFIG = require("kulala.config")

local M = {}

---User-configured path from setup (`kulala_core_path`), if any.
---@return string|nil
local function configured_core_path()
  local p = CONFIG.get().kulala_core_path
  if type(p) == "string" and vim.trim(p) ~= "" then return vim.trim(p) end
  return nil
end

---Resolve kulala-core executable: explicit `kulala_core_path` wins; otherwise `kulala-core` on PATH.
---@return string|nil
function M.executable_path()
  local configured = configured_core_path()
  if configured then
    if vim.fn.executable(configured) == 1 then return vim.fn.exepath(configured) end
    return nil
  end
  if vim.fn.executable("kulala-core") == 1 then return vim.fn.exepath("kulala-core") end
  return nil
end

function M.enabled()
  return M.executable_path() ~= nil
end

function M.require_enabled()
  local exe = M.executable_path()
  if exe then return exe end

  local configured = configured_core_path()
  if configured then error(("kulala_core_path is not executable: %s"):format(configured), 0) end
  error("kulala-core not found on PATH. Install kulala-core or set `kulala_core_path` in your kulala setup.", 0)
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
  local dir = CONFIG.get().kulala_core_data_dir
  if type(dir) == "string" and dir ~= "" then return dir end
  return default_kulala_core_data_dir()
end

local function env_with_data_dir()
  local env = vim.fn.environ()
  env.KULALA_CORE_DATA_DIR = M.effective_data_dir()
  return env
end

---Subprocess timeout (ms). Uses `kulala_core_timeout`, else 10 minutes.
---@return number|nil nil disables vim.system timeout (not recommended)
local function invoke_timeout_ms()
  local t = CONFIG.get().kulala_core_timeout
  if t == nil then return 600000 end
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

---@param payload table
---@param cwd string|nil
---@return vim.SystemCompleted
function M.invoke(payload, cwd)
  local exe = M.require_enabled()
  local opts = {
    stdin = vim.json.encode(payload) .. "\n",
    text = true,
    env = env_with_data_dir(),
  }
  local timeout_ms = invoke_timeout_ms()
  if timeout_ms then opts.timeout = timeout_ms end
  if type(cwd) == "string" and cwd ~= "" and vim.fn.isdirectory(cwd) == 1 then opts.cwd = cwd end
  return vim.system({ exe }, opts):wait()
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

---@param stdout string|nil
---@return table|nil
local function try_decode_wrapper(stdout)
  local raw = vim.trim(stdout or "")
  if raw == "" then return nil end
  local ok, w = pcall(vim.json.decode, raw)
  if ok and type(w) == "table" and w.type then return w end
  return nil
end

---@param content string
---@param filepath string|nil
---@param cwd_override string|nil
---@return table|nil doc
---@return string|nil err
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

---@param payload table
---@param cwd string|nil
---@return table|nil wrapper
---@return string|nil err
function M.run(payload, cwd)
  M.require_enabled()
  payload.action = "run"
  local job = M.invoke(payload, cwd)
  local wrapper = try_decode_wrapper(job.stdout)
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

---@param payload { promptId: string, inputs: { id: string, value: string }[] }
---@param cwd string|nil
---@return table|nil wrapper
---@return string|nil err
function M.continue(payload, cwd)
  M.require_enabled()
  payload.action = "continue"
  local job = M.invoke(payload, cwd)
  local wrapper = try_decode_wrapper(job.stdout)
  if wrapper then return wrapper, nil end
  if job.code ~= 0 then
    local err = vim.trim(job.stderr or "")
    if err == "" then err = "kulala-core continue failed (exit " .. tostring(job.code) .. ")" end
    return nil, err
  end
  return nil, "invalid kulala-core continue output"
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

---@param opts { url: string, method?: string, headers?: table, body?: string, insecure?: boolean, timeoutSec?: number, connectionTimeoutSec?: number }
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
