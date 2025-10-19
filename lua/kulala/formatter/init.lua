--- Formatter utils for one-off formatting tasks

local Config = require("kulala.config")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

M.format = function(ft, formatter, contents, opts)
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

  if executable == "prettier" and vim.fn.executable("prettierd") == 1 then
    formatter = { "prettierd", "file." .. ft } -- prettierd requires a file path to determine the parser
    executable = "prettierd"
  end

  local result = Shell.run(formatter, {
    sync = true,
    stdin = contents,
    err_msg = "Failed to format with " .. executable .. (opts.line and " at line " .. opts.line + 1 or ""),
    abort_on_stderr = true,
  })

  if not result or result.code ~= 0 or result.stderr ~= "" or result.stdout == "" then return contents end

  return opts.escape and result.stdout or result.stdout:gsub("\\/", "/"):gsub('\\"', '"')
end

M.json = function(contents, opts)
  local formatter = Config.get().contenttypes["application/json"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end

  local ft = formatter.ft
  formatter = vim.deepcopy(formatter.formatter)

  opts = vim.tbl_deep_extend("keep", opts or {}, { sort = true })
  _ = opts.sort and table.insert(formatter, 2, "--sort-keys")

  contents = type(contents) == "table" and vim.json.encode(contents, opts) or contents

  return M.format(ft, formatter, contents, opts)
end

M.graphql = function(contents, opts)
  local formatter = Config.get().contenttypes["application/graphql"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end

  return M.format(formatter.ft, formatter.formatter, contents, opts)
end

M.js = function(contents, opts)
  local formatter = Config.get().contenttypes["application/javascript"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end

  return M.format(formatter.ft, formatter.formatter, contents, opts)
end

M.lua = function(contents, opts)
  local formatter = Config.get().contenttypes["application/lua"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end

  return M.format(formatter.ft, formatter.formatter, contents, opts)
end

M.html = function(contents, opts)
  local formatter = Config.get().contenttypes["application/html"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end

  return M.format(formatter.ft, formatter.formatter, contents, opts)
end

M.xml = function(contents, opts)
  local formatter = Config.get().contenttypes["application/xml"]
  if not (formatter and type(formatter.formatter) == "table") then return contents end

  return M.format(formatter.ft, formatter.formatter, contents, opts)
end

return M
