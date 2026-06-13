local dynamic_vars = require("kulala.parser.dynamic_vars")
local fs = require("kulala.utils.fs")

local h = require("kulala.test_helper.ui")

local Jobstart = { id = "Jobstart", jobs = {} }
local System = { id = "System", code = 0, signal = 0, pid = 0, closing = false, jobs = {}, log = {}, async = false }
local Input = { variables = {} }
local Output = { log = {} }
local Notify = { messages = {} }
local Fs = { paths_mappings = {} }
local Dynamic_vars = {}

---@diagnostic disable: duplicate-set-field

-- Disable check for read-only fields as we
-- need to override them for stubbing.
-- luacheck: ignore 122

setmetatable(Jobstart, {
  __call = function(_, ...)
    return Jobstart.run(...)
  end,
})

setmetatable(System, {
  __call = function(_, ...)
    return System.run(...)
  end,
})

setmetatable(Input, {
  __call = function(_, ...)
    return Input.run(...)
  end,
})

setmetatable(Notify, {
  __call = function(_, ...)
    return Notify.run(...)
  end,
})

setmetatable(Output, {
  __call = function(_, ...)
    return Output.run(...)
  end,
})

Dynamic_vars.retrieve_all = function()
  return Dynamic_vars
end

Dynamic_vars.stub = function(variables)
  Dynamic_vars._retrieve_all = dynamic_vars._retrieve_all or dynamic_vars.retrieve_all
  dynamic_vars.retrieve_all = Dynamic_vars.retrieve_all

  vim.iter(variables or {}):each(function(k, v)
    Dynamic_vars[k] = function()
      return v
    end
  end)

  return Dynamic_vars
end

Dynamic_vars.reset = function()
  dynamic_vars.retrieve_all = Dynamic_vars._retrieve_all
end

Notify.stub = function()
  Notify._notify = Notify._notify or vim.notify
  ---
  vim.notify = Notify
  return Notify
end

Notify.run = function(message, level, opts)
  vim.list_extend(Notify.messages, { message })
  Notify._notify(message, level, opts)
end

Notify.has_message = function(message)
  return vim.iter(Notify.messages):any(function(m)
    return m:find(message, 1, true)
  end)
end

Notify.reset = function()
  vim.notify = Notify._notify
  Notify.messages = {}
end

Input.stub = function(variables)
  Input._input = Input._input or vim.fn.input
  vim.fn.input = Input

  vim.iter(variables or {}):each(function(k, v)
    Input.variables[k] = v
  end)
  return Input
end

Input.run = function(prompt)
  return Input.variables[prompt]
end

Input.reset = function()
  vim.fn.input = Input._input
  Input.variables = {}
end

Output.spy = function()
  Output._spy = true
  return Output.stub()
end

Output.stub = function()
  Output._write = Output._write or io.write
  Output._print = Output._print or vim.print
  Output._notify = Output._notify or vim.notify

  io.write = function(...)
    Output.run("_write", ...)
  end
  vim.print = function(...)
    Output.run("_print", ...)
  end
  vim.notify = function(message)
    Output.run("_notify", message)
  end

  return Output
end

Output.run = function(f, ...)
  local _ = Output._spy and Output[f](...)
  for _, c in ipairs { ... } do
    _ = not c:match("^\n+$") and table.insert(Output.log, c)
  end
end

Output.reset = function()
  io.write = Output._write
  vim.print = Output._print
  vim.notify = Output._notify

  Output.log = {}
  Output.spy = false
end

---@param paths_mappings table [path:content]
function Fs:stub_read_file(paths_mappings)
  Fs._read_file = Fs._read_file or fs.read_file
  Fs._file_exists = Fs._file_exists or fs.file_exists

  fs.read_file = self.read_file
  fs.file_exists = self.file_exists

  self.paths_mappings = vim.tbl_extend("force", self.paths_mappings, paths_mappings)

  return self
end

function Fs:read_file_reset()
  fs.read_file = self._read_file
  fs.file_exists = self._file_exists

  self.paths_mappings = {}
end

function Fs.read_file(path)
  return Fs.paths_mappings[path] or Fs._read_file(path)
end

function Fs.file_exists(path)
  return Fs.paths_mappings[path] or Fs._file_exists(path)
end

function Jobstart.stub(cmd, opts)
  Jobstart.cmd = cmd
  Jobstart.opts = opts

  Jobstart._jobstart = Jobstart._jobstart or vim.fn.jobstart
  vim.fn.jobstart = Jobstart

  return Jobstart
end

function Jobstart.reset()
  vim.fn.jobstart = Jobstart._jobstart
  Jobstart.jobs = {}
end

local function job_cmd_match(cmd, cmd_stub)
  return vim.iter(cmd_stub):any(function(flag)
    return vim.iter(cmd):any(function(part)
      return part == flag or (type(part) == "string" and part:find(flag, 1, true))
    end)
  end)
end

local KulalaCore = {
  run_mappings = {},
  requests_no = 0,
  requests = {},
}

---@param headers_text string
---@return table<string, string>
local function parse_headers_text(headers_text)
  local headers = {}
  for line in vim.gsplit(headers_text or "", "\n", { plain = true, trimempty = true }) do
    local k, v = line:match("^([^:]+):%s*(.*)$")
    if k and not k:match("^HTTP/") then headers[k] = v end
  end
  return headers
end

---@param payload table
---@return string|nil
local function url_for_run_payload(payload)
  local content = payload.content or ""
  local line = payload.limit and payload.limit[1] and payload.limit[1].line
  if type(line) == "number" and line > 0 then
    local lineno = 0
    local current_url
    for l in vim.gsplit(content, "\n", { plain = true }) do
      lineno = lineno + 1
      local u = l:match("(wss?://%S+)") or l:match("(https?://%S+)")
      if u then current_url = vim.split(u, "?")[1] end
      if lineno >= line and current_url then return current_url end
    end
  end
  return content:match("(wss?://[%w%-%.:/_]+)") or content:match("(https?://[%w%-%.:/_]+)")
end

---@param url string
---@param mapping table
---@return table
local function build_websocket_item(url, mapping)
  return {
    success = true,
    protocol = "websocket",
    url = url,
    initialMessage = mapping.body or "",
    request = { method = "WS", url = url },
  }
end

---@param url string
---@param mapping table
---@return table
local function build_success_item(url, mapping)
  if url:match("^wss?://") then return build_websocket_item(url, mapping) end

  local headers_text = mapping.headers or ""
  local body = mapping.body or ""
  local errors = mapping.errors or ""
  local status = mapping.status or 200
  if mapping.stats then
    local ok, stats = pcall(vim.json.decode, mapping.stats)
    if ok and type(stats) == "table" and stats.response_code then status = stats.response_code end
  end

  local method = mapping.method or "GET"

  return {
    success = true,
    status = status,
    url = url,
    headers = parse_headers_text(headers_text),
    body = { type = "text", content = body },
    timings = {
      dns = 5.449,
      tcp = 35.805,
      tls = 150.167,
      request = 0,
      redirect = 0,
      firstByte = 150.565,
      startTransfer = 150.565,
      total = 492,
    },
    verboseTrace = errors,
    scriptConsole = mapping.script_console,
    request = {
      method = method,
      url = url,
    },
  }
end

function KulalaCore.stub(opts)
  KulalaCore.run_mappings = vim.tbl_deep_extend("force", KulalaCore.run_mappings, opts or {})
  return KulalaCore
end

function KulalaCore.reset()
  KulalaCore.requests_no = 0
  KulalaCore.requests = {}
  KulalaCore.run_mappings = {}
end

function KulalaCore.is_invocation(cmd)
  return job_cmd_match(cmd, { "kulala-core" })
end

---@param system table
function KulalaCore.handle(system)
  local stdin = (system.args.opts or {}).stdin or ""
  local payload = vim.json.decode(stdin:match("^(.-)\n?$") or stdin) or {}
  local action = payload.action

  if action == "parse" or action == "environments" or action == "from_curl" then
    local done = false
    System._system(system.args.cmd, system.args.opts, function(completed)
      system.code = completed.code
      system.stdout = completed.stdout or ""
      system.stderr = completed.stderr or ""
      done = true
    end)
    vim.wait(60000, function()
      return done
    end, 20)
    return
  end

  if action == "inspect_request" or action == "to_curl" then
    local content = payload.content or ""
    local line = payload.line or 1
    local lines_tbl = vim.split(content, "\n", { plain = true })
    local block_start = 1
    for i = line, 1, -1 do
      if (lines_tbl[i] or ""):match("^###") then
        block_start = i
        break
      end
    end
    local vars = {}
    local method, url, httpver
    local headers = {}
    local body_lines = {}
    local phase = "preamble"
    for i = block_start, #lines_tbl do
      local l = lines_tbl[i] or ""
      if i > block_start and l:match("^###") then break end
      local k, v = l:match("^@([%w_%.%-]+)%s*=%s*(.+)$")
      if k and v then vars[k] = v:gsub("^%s+", ""):gsub("%s+$", "") end
      if not method then
        method, url, httpver = l:match("^(%u+)%s+(%S+)%s*(HTTP/%S*)")
        if method then phase = "headers" end
      elseif phase == "headers" and l:find(":") then
        local hk, hv = l:match("^([^:]+):%s*(.*)$")
        if hk then
          headers[hk] = (hv or ""):gsub("{{([^}]+)}}", function(n)
            return vars[n:match("%s*(.-)%s*")] or ""
          end)
        end
      elseif phase == "headers" and l == "" then
        phase = "body"
      elseif phase == "body" then
        table.insert(body_lines, l)
      end
    end
    url = (url or ""):gsub("{{([^}]+)}}", function(n)
      return vars[n:match("%s*(.-)%s*")] or ""
    end)
    for k, v in pairs(headers) do
      headers[k] = v:gsub("{{([^}]+)}}", function(n)
        return vars[n:match("%s*(.-)%s*")] or ""
      end)
    end
    for i, bl in ipairs(body_lines) do
      body_lines[i] = bl:gsub("{{([^}]+)}}", function(n)
        return vars[n:match("%s*(.-)%s*")] or ""
      end)
    end
    local method_upper = (method or ""):upper()
    if method_upper == "GRPC" or method_upper == "WS" or method_upper == "WSS" then
      system.code = 0
      system.stdout = vim.json.encode {
        ok = false,
        error = method_upper .. " requests cannot be shown as curl or HTTP inspect preview",
      }
      system.stderr = ""
      return
    end
    if action == "inspect_request" then
      local out = { (method or "GET") .. " " .. (url or "") .. (httpver and (" " .. httpver) or "") }
      for k, v in pairs(headers) do
        table.insert(out, k .. ": " .. v)
      end
      if #body_lines > 0 then
        table.insert(out, "")
        for _, bl in ipairs(body_lines) do
          table.insert(out, bl)
        end
      end
      system.code = 0
      system.stdout = vim.json.encode { ok = true, lines = out }
    else
      local body = table.concat(body_lines, "\n")
      local curl = ("curl -X '%s' -v -s"):format(method or "GET")
      for k, v in pairs(headers) do
        if k:lower() ~= "cookie" then curl = curl .. (" -H '%s:%s'"):format(k, v) end
      end
      if body ~= "" then curl = curl .. (" --data-binary '%s'"):format(body) end
      local cookie = headers.Cookie or headers.cookie
      if cookie then curl = curl .. (" --cookie '%s'"):format(cookie) end
      curl = curl .. (" '%s'"):format(url or "")
      system.code = 0
      system.stdout = vim.json.encode { ok = true, curl = curl }
    end
    system.stderr = ""
    return
  end

  if action == "run" or action == "continue" then
    local url = url_for_run_payload(payload)
    url = url and vim.split(url, "?")[1]
    local mapping = url and KulalaCore.run_mappings[url]
    local data = {}
    if mapping then
      table.insert(data, build_success_item(url, mapping))
      KulalaCore.requests_no = KulalaCore.requests_no + 1
      table.insert(KulalaCore.requests, url)
    end

    system.code = #data > 0 and 0 or 1
    system.stdout = vim.json.encode { type = "responses", data = data }
    system.stderr = ""
    return
  end

  system.code = 1
  system.stdout = ""
  system.stderr = "unsupported kulala-core action in test stub"
end

function Jobstart.run(cmd, opts)
  Jobstart.args = { cmd = cmd, opts = opts }

  if not job_cmd_match(cmd, Jobstart.cmd) then return Jobstart._jobstart(cmd, opts) end

  local job_id = "job_id_" .. tostring(math.random(10000))
  Jobstart.jobs[job_id] = true

  local _ = Jobstart.opts.on_call and Jobstart.opts.on_call(Jobstart)

  _ = opts.on_stdout and opts.on_stdout(_, h.to_table(Jobstart.opts.on_stdout), _)
  _ = opts.on_stderr and opts.on_stderr(_, h.to_table(Jobstart.opts.on_stderr))
  _ = opts.on_exit and opts.on_exit(_, Jobstart.opts.on_exit)

  Jobstart.jobs[job_id] = nil

  return job_id
end

function Jobstart.wait(timeout, predicate)
  predicate = predicate or function() end
  vim.wait(timeout, function()
    return vim.tbl_count(Jobstart.jobs) == 0 and predicate()
  end)
end

function System.stub(cmd, opts, on_exit)
  System.cmd = cmd
  System.opts = opts

  System.write = opts.write
  System.kill = opts.kill
  System.write_to = opts.write_to

  System.on_exit = on_exit

  System._system = System._system or vim.system
  vim.system = System

  return System
end

function System.reset()
  vim.system = System._system
  System.jobs = {}
  System.log = {}
  System.async = false
end

function System.run(cmd, opts, on_exit)
  System.args = { cmd = cmd, opts = opts or {}, on_exit = on_exit }
  System.args.opts.on_exit = on_exit

  if not job_cmd_match(cmd, System.cmd) then return System._system(cmd, opts, on_exit) end

  local job_id = "job_id_" .. tostring(math.random(10000))
  System.jobs[job_id] = true
  local _

  _ = System.opts.on_call and System.opts.on_call(System)

  System.completed = {
    code = System.code,
    signal = System.signal,
    stderr = System.stderr,
    stdout = System.stdout,
  }

  _ = opts.stdout and opts.stdout(_, System.stdout)
  _ = opts.stderr and opts.stderr(_, System.stderr)
  _ = on_exit and not System.async and on_exit(System.completed)

  System.jobs[job_id] = nil
  return System
end

function System.is_closing()
  return System.closing
end

function System.add_log(entry)
  table.insert(System.log, entry)
end

function System.wait(_, timeout, predicate)
  predicate = predicate or function() end

  vim.wait(timeout or 0, function()
    return vim.tbl_count(System.jobs) == 0 and predicate()
  end)

  return System.completed
end

return {
  Jobstart = Jobstart,
  System = System,
  KulalaCore = KulalaCore,
  Fs = Fs,
  Notify = Notify,
  Input = Input,
  Output = Output,
  Dynamic_vars = Dynamic_vars,
}
