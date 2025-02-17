local dynamic_vars = require("kulala.parser.dynamic_vars")
local fs = require("kulala.utils.fs")

local h = require("test_helper.ui")

local Jobstart = { id = "Jobstart", jobs = {} }
local System = { id = "System", code = 0, signal = 0, jobs = {} }
local Curl = { url_mappings = {}, paths = {}, requests = {}, requests_no = 0, last_request_body_path = "" }
local Input = { variables = {} }
local Notify = { messages = {} }
local Fs = { paths_mappings = {} }
local Dynamic_vars = {}

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
  vim.notify = Input._notify
  Input.variables = {}
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

function Curl.stub(opts)
  Curl.url_mappings = vim.tbl_deep_extend("force", Curl.url_mappings, opts)
  return Curl
end

local function parse_curl_cmd(cmd)
  local curl_flags = {
    ["-D"] = "headers_path",
    ["-o"] = "body_path",
    ["-w"] = "curl_format_path",
    ["--cookie-jar"] = "cookies_path",
    ["--data-binary"] = "request_body",
  }

  local flags = {}
  local previous

  for _, flag in ipairs(cmd) do
    local flag_name = curl_flags[previous]
    if flag_name then flags[flag_name] = flag end
    previous = flag
  end

  return flags
end

function Curl.request(job)
  local cmd = job.args.cmd
  local url = vim.split(cmd[#cmd], "?")[1]
  local mappings = vim.tbl_deep_extend("force", Curl.url_mappings["*"], Curl.url_mappings[url] or {})

  if not mappings then return end

  if job.id == "Jobstart" then
    job.opts.on_stdout = mappings.stats
    job.opts.on_stderr = mappings.errors
  else
    job.stdout = mappings.stats
    job.stderr = mappings.errors
  end

  local curl_flags = parse_curl_cmd(cmd)

  _ = (mappings.headers and curl_flags.headers_path) and fs.write_file(curl_flags.headers_path, mappings.headers)
  _ = (mappings.body and curl_flags.body_path) and fs.write_file(curl_flags.body_path, mappings.body)

  vim.list_extend(Curl.paths, { curl_flags.headers_path, curl_flags.body_path })

  Curl.last_request_body_path = (curl_flags["request_body"] or ""):sub(2)
  Curl.requests_no = Curl.requests_no + 1
  vim.list_extend(Curl.requests, { url })
end

function Curl.reset()
  Curl.requests_no = 0
  Curl.requests = {}

  vim.iter(Curl.paths):each(function(path)
    vim.uv.fs_unlink(path)
  end)
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
  return vim.iter(cmd_stub):all(function(flag)
    return vim.tbl_contains(cmd, flag)
  end)
end

function Jobstart.run(cmd, opts)
  Jobstart.args = { cmd = cmd, opts = opts }

  if not job_cmd_match(cmd, Jobstart.cmd) then return Jobstart._jobstart(cmd, opts) end

  local job_id = "job_id_" .. tostring(math.random(10000))
  Jobstart.jobs[job_id] = true

  _ = Jobstart.opts.on_call and Jobstart.opts.on_call(Jobstart)

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
  System.on_exit = on_exit

  System._system = System._system or vim.system
  vim.system = System

  return System
end

function System.reset()
  vim.system = System._system
  System.jobs = {}
end

function System.run(cmd, opts, on_exit)
  System.args = { cmd = cmd, opts = opts, on_exit = on_exit }

  if not job_cmd_match(cmd, System.cmd) then return System._system(cmd, opts, on_exit) end

  local job_id = "job_id_" .. tostring(math.random(10000))
  System.jobs[job_id] = true

  _ = System.opts.on_call and System.opts.on_call(System)

  System.completed = {
    code = System.code,
    signal = System.signal,
    stderr = System.stderr,
    stdout = System.stdout,
  }

  _ = opts.stdout and opts.stdout(_, System.stdout)
  _ = opts.stderr and opts.stderr(_, System.stderr)
  _ = on_exit and on_exit(System.completed)

  System.jobs[job_id] = nil
  return System
end

function System.wait(_, timeout, predicate)
  predicate = predicate or function() end

  vim.wait(timeout or 0, function()
    return vim.tbl_count(System.jobs) == 0 and predicate()
  end)

  return System.completed
end

return {
  Curl = Curl,
  Jobstart = Jobstart,
  System = System,
  Fs = Fs,
  Notify = Notify,
  Input = Input,
  Dynamic_vars = Dynamic_vars,
}
