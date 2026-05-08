local CONFIG = require("kulala.config")

local M = {}

---@return string|nil
function M.executable_path()
  local p = CONFIG.get().kulala_core_path
  if type(p) ~= "string" or p == "" then return nil end
  if vim.fn.executable(p) == 1 then return vim.fn.exepath(p) end
  return nil
end

function M.enabled()
  return M.executable_path() ~= nil
end

---Matches `packages/core/src/lib/runner/external-tools/paths.ts` (`getKulalaCoreDataDir`).
---Previously we used `stdpath("data")/kulala-core` (~/.local/share/nvim/kulala-core), which broke parity with the kulala-core CLI and left stale OAuth DB after deleting ~/.local/share/kulala-core.
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

---Resolved persistence directory (override or same default kulala-core CLI uses).
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

---Resolve absolute path for kulala-core stdin and subprocess cwd.
---OAuth / http-client.env.json discovery uses `dirname(filepath)` when filepath is sent; otherwise kulala-core uses `process.cwd()` (the cwd we pass to `vim.system`).
---If the buffer path resolves to a non-existent file (wrong cwd + relative name), omit filepath so OAuth walks from `cwd` instead of a bogus directory.
---@param bufnr integer
---@param explicit_path string|nil path from parser (`parsed_request.file`) or caller (`get_document(lines, path)`)
---@return string|nil filepath absolute readable path, or nil to omit from JSON
---@return string cwd for kulala-core subprocess
---@return string display_path best-effort path for `DocumentRequest.file`
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

---@param payload table must include `action`
---@param cwd string|nil if set, kulala-core runs with this working directory (matches CLI when run from the `.http` folder). OAuth walks parents of `dirname(filepath)` but falls back to `cwd()` when filepath is missing.
---@return vim.SystemCompleted
function M.invoke(payload, cwd)
  local exe = assert(M.executable_path())
  local opts = {
    -- Trailing newline matches shell `echo '{...}' | kulala-core` and avoids rare stdin edge cases.
    stdin = vim.json.encode(payload) .. "\n",
    text = true,
    env = env_with_data_dir(),
  }
  if type(cwd) == "string" and cwd ~= "" and vim.fn.isdirectory(cwd) == 1 then opts.cwd = cwd end
  return vim.system({ exe }, opts):wait()
end

---@param first table|nil
---@return boolean
local function is_prompt_item(first)
  if type(first) ~= "table" then return false end
  if first.prompt == true then return true end
  -- Some JSON decoders / cores may represent booleans differently; promptId + promptType is unambiguous.
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

---Decode stdout JSON; used even when exit code != 0 (some builds still write a valid prompt wrapper).
---@param stdout string|nil
---@return table|nil
local function try_decode_wrapper(stdout)
  local raw = vim.trim(stdout or "")
  if raw == "" then return nil end
  local ok, w = pcall(vim.json.decode, raw)
  if ok and type(w) == "table" and w.type then return w end
  return nil
end

---Parse HTTP document via kulala-core (`action: parse`).
---@param content string
---@param filepath string|nil
---@param cwd_override string|nil if set, subprocess cwd (e.g. from `resolve_document_paths`)
---@return table|nil doc
---@return string|nil err
function M.parse_document(content, filepath, cwd_override)
  if not M.enabled() then return nil, "kulala_core_path not configured" end
  local cwd = cwd_override
  if not cwd and type(filepath) == "string" and filepath ~= "" then
    local d = vim.fn.fnamemodify(filepath, ":h")
    if vim.fn.isdirectory(d) == 1 then cwd = d end
  end
  local payload = { action = "parse", content = content }
  if type(filepath) == "string" and filepath ~= "" then payload.filepath = filepath end
  local job = M.invoke(payload, cwd)
  if job.code ~= 0 then
    return nil, vim.trim(job.stderr or "") ~= "" and vim.trim(job.stderr) or "kulala-core parse failed"
  end
  local ok, doc = pcall(vim.json.decode, job.stdout)
  if not ok or type(doc) ~= "table" then return nil, "invalid kulala-core parse output" end
  return doc, nil
end

---Run request(s) via kulala-core (`action: run`).
---@param payload table action, content, filepath, env, limit
---@param cwd string|nil working directory for kulala-core (dirname of `.http` file)
---@return table|nil wrapper KulalaResponseWrapper
---@return string|nil err
function M.run(payload, cwd)
  if not M.enabled() then return nil, "kulala_core_path not configured" end
  payload.action = "run"
  local job = M.invoke(payload, cwd)
  local wrapper = try_decode_wrapper(job.stdout)
  local first = wrapper and wrapper.data and wrapper.data[1]
  local is_prompt = wrapper and wrapper.type == "responses" and is_prompt_item(first)

  if job.code ~= 0 and not is_prompt then
    local err = vim.trim(job.stderr or "")
    if err == "" then err = "kulala-core run failed (exit " .. tostring(job.code) .. ")" end
    return nil, err
  end

  if not wrapper or type(wrapper) ~= "table" then return nil, "invalid kulala-core run output" end
  return wrapper, nil
end

---Continue a kulala-core prompt (OAuth2 redirect URL, @kulala-prompt vars, etc.) (`action: continue`).
---@param payload { promptId: string, inputs: { id: string, value: string }[] }
---@param cwd string|nil same cwd as the preceding `run` (OAuth continuation)
---@return table|nil wrapper KulalaResponseWrapper
---@return string|nil err
function M.continue(payload, cwd)
  if not M.enabled() then return nil, "kulala_core_path not configured" end
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

return M
