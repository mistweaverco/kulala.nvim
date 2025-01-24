
local fs = require("kulala.utils.fs")

_G._Jobstart_jobs = {}

local Jobstart = {}
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

function Jobstart:__call(cmd, opts)
  self:run(cmd, opts)
end

function Jobstart:stub(cmd, opts)
  self = vim.tbl_extend("force", self, opts, { cmd = cmd })
  setmetatable(self, Jobstart)

  Jobstart._jobstart = Jobstart._jobstart and Jobstart._jobstart or vim.fn.jobstart
  vim.fn.jobstart = self

  self.job_id = "job_id_" .. tostring(math.random(10000))
  _Jobstart_jobs[self.job_id] = true

  return self
end

function Jobstart:reset()
  vim.fn.jobstart = Jobstart._jobstart
  _Jobstart_jobs = {}
end

function Jobstart:run(cmd, opts)
  self.args = { cmd, opts }

  _ = opts.on_stdout and opts.on_stdout(_, self.on_stdout, _)
  _ = opts.on_stderr and opts.on_stderr(_, self.on_stderr)
  _ = opts.on_exit and opts.on_exit(_, self.on_exit)
  _Jobstart_jobs[self.job_id] = nil
end

function Jobstart:wait(timeout)
  vim.wait(timeout, function()
    return vim.fn.len(_Jobstart_jobs) == 0
  end)
end

return {
  Jobstart = Jobstart,
  Fs = Fs
}
