local Config = require("kulala.config")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

M.format = function(formatter, contents, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    escape = true,
    verbose = true,
  })

  if type(formatter) == "function" then return formatter(contents) end
  if not type(formatter) == "table" then return contents end

  local executable = formatter[1]

  if vim.fn.executable(executable) == 0 then
    _ = opts.versbose and Logger.warn("Formatting failed: " .. executable .. " is not available.")
    return contents
  end

  local result = Shell.run(formatter, {
    sync = true,
    stdin = contents,
    err_msg = "Failed to format with " .. executable,
    abort_on_stderr = true,
  })

  if not result or result.code ~= 0 or result.stderr ~= "" or result.stdout == "" then return contents end

  return opts.escape and result.stdout or result.stdout:gsub("\\/", "/"):gsub('\\"', '"')
end

M.json = function(contents, opts)
  local formatter = Config.get().contenttypes["application/json"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end

  formatter = vim.deepcopy(formatter.formatter)

  opts = vim.tbl_deep_extend("keep", opts or {}, { sort = true })
  _ = opts.sort and table.insert(formatter, 2, "--sort-keys")

  contents = type(contents) == "table" and vim.json.encode(contents, opts) or contents

  return M.format(formatter, contents, opts)
end

M.graphql = function(contents, opts)
  local formatter = Config.get().contenttypes["application/graphql"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end

  return M.format(formatter.formatter, contents, opts)
end

M.html = function(contents, opts)
  local formatter = Config.get().contenttypes["application/html"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end
  return M.format(formatter.formatter, contents, opts)
end

M.xml = function(contents, opts)
  local formatter = Config.get().contenttypes["application/xml"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end
  return M.format(formatter.formatter, contents, opts)
end

return M
