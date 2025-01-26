local fs = require("kulala.utils.fs")
local h = require("test_helper.ui")

local Curl = {}
local Jobstart = { jobs = {} }
local System = { code = 0, signal = 0, jobs = {} }

local Fs = { paths_mappings = {} }

---@param paths_mappings table [path:content]
function Fs:stub_read_file(paths_mappings)
  Fs._read_file = Fs._read_file and Fs._read_file or fs.read_file
  Fs._file_exists = Fs._file_exists and Fs._file_exists or fs.file_exists

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

function Curl:stub(opts)
  self = vim.tbl_extend("force", self, {
    url_mappings = opts,
    requests = {},
    requests_no = 0,
  })
  return setmetatable(self, Curl)
end

local function parse_curl_cmd(cmd)
  local curl_flags = {
    ["-D"] = "headers",
    ["-o"] = "body",
    ["-w"] = "curl_format",
    ["--cookie-jar"] = "cookies",
  }

  local flags = {}
  local previous

  for _, flag in ipairs(cmd) do
    local flag_name = curl_flags[previous]
    if flag_name then
      flags[flag_name] = flag
    end
    previous = flag
  end

  return flags
end

function Curl:request(job)
  local cmd = job.args.cmd
  local url = cmd[#cmd]
  local mappings = vim.tbl_extend("force", self.url_mappings["*"], self.url_mappings[url])

  if not mappings then
    return
  end

  job.on_stdout = mappings.stats
  job.on_stderr = mappings.errors

  local curl_flags = parse_curl_cmd(cmd)
  fs.write_file(curl_flags.headers, mappings.headers)
  fs.write_file(curl_flags.body, mappings.body)

  self.requests_no = self.requests_no + 1
  vim.list_extend(self.requests, { url })
end

function Curl:reset()
  self.requests_no = 0
  self.requests = {}
end

function Jobstart:__call(cmd, opts)
  return self:run(cmd, opts)
end

function Jobstart:stub(cmd, opts)
  self = vim.tbl_extend("force", self, opts, { cmd = cmd })

  Jobstart._jobstart = Jobstart._jobstart and Jobstart._jobstart or vim.fn.jobstart
  vim.fn.jobstart = self

  self.job_id = "job_id_" .. tostring(math.random(10000))
  Jobstart.jobs[self.job_id] = true

  return setmetatable(self, Jobstart)
end

function Jobstart:reset()
  vim.fn.jobstart = Jobstart._jobstart
  Jobstart.jobs = {}
end

local function job_cmd_match(cmd, cmd_stub)
  return vim.iter(cmd_stub):all(function(flag)
    return vim.tbl_contains(cmd, flag)
  end)
end

function Jobstart:run(cmd, opts)
  if not job_cmd_match(cmd, self.cmd) then
    Jobstart._jobstart(cmd, opts)
    return
  end

  self.args = { cmd = cmd, opts = opts }

  _ = self.on_call and self.on_call(self)

  _ = opts.on_stdout and opts.on_stdout(_, h.to_table(self.on_stdout), _)
  _ = opts.on_stderr and opts.on_stderr(_, h.to_table(self.on_stderr))
  _ = opts.on_exit and opts.on_exit(_, self.on_exit)

  Jobstart.jobs[self.job_id] = nil
end

function Jobstart:wait(timeout, predicate)
  predicate = predicate or function() end
  vim.wait(timeout, function()
    return vim.tbl_count(Jobstart.jobs) == 0 and predicate()
  end)
end

System.__index = System

function System:__call(cmd, opts, on_exit)
  return self:run(cmd, opts, on_exit)
end

function System:stub(cmd, opts, on_exit)
  self = vim.tbl_extend("force", self, opts, {
    cmd = cmd,
    on_exit = on_exit,
  })

  System._system = System._system and System._system or vim.system
  vim.system = self

  self.job_id = "job_id_" .. tostring(math.random(10000))
  System.jobs[self.job_id] = true

  return setmetatable(self, System)
end

function System:reset()
  vim.system = System._system
  System.jobs = {}
end

function System:run(cmd, opts, on_exit)
  if not job_cmd_match(cmd, self.cmd) then
    System._system(cmd, opts, on_exit)
    return
  end

  self.args = { cmd = cmd, opts = opts, on_exit = on_exit }

  local stats = {
    code = self.code,
    signal = self.signal,
    stderr = self.stderr,
    stdout = self.stdout,
  }
  _ = self.on_call and self.on_call(self)

  _ = opts.stdout and opts.stdout(_, self.stdout)
  _ = opts.stderr and opts.stderr(_, self.stderr)
  _ = on_exit and on_exit(stats)

  System.jobs[self.job_id] = nil

  return setmetatable(stats, self)
end

function System:wait(timeout, predicate)
  predicate = predicate or function() end

  vim.wait(timeout or 0, function()
    return vim.tbl_count(System.jobs) == 0 and predicate()
  end)

  return self
end

return {
  Curl = Curl,
  Jobstart = Jobstart,
  System = System,
  Fs = Fs,
}
