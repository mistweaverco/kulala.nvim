local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local M = {}

-- Function to access a nested key in a table dynamically
local function get_nested_value(t, key)
  local keys = vim.split(key, "%.")
  local value = t
  for _, k in ipairs(keys) do
    value = value[k]
    if value == nil then
      return nil
    end
  end
  return value
end

local get_headers_as_table = function()
  local headers_file = FS.read_file(GLOBALS.HEADERS_FILE)
  local lines = vim.split(headers_file, "\r\n")
  local headers_table = {}
  for _, header in ipairs(lines) do
    if header:find(":") ~= nil then
      local kv = vim.split(header, ":")
      local key = kv[1]:lower()
      -- the value should be everything after the first colon
      -- but we can't use slice and join because the value might contain colons
      local value = header:sub(#key + 2)
      headers_table[key] = value
    end
  end
  return headers_table
end

M.env_header_key = function(cmd)
  local headers = get_headers_as_table()
  local kv = vim.split(cmd, " ")
  local header_key = kv[2]
  local variable_name = kv[1]
  local value = headers[header_key:lower()]
  if value == nil then
    vim.notify("env-header-key --> Header not found.", vim.log.levels.ERROR)
  else
    vim.fn.setenv(variable_name, value)
  end
end

M.env_json_key = function(cmd, body)
  local json = vim.fn.json_decode(body)
  if json == nil then
    vim.notify("env-json-key --> JSON parsing failed.", vim.log.levels.ERROR)
  else
    local kv = vim.split(cmd, " ")
    local value = get_nested_value(json, kv[2])
    vim.fn.setenv(kv[1], value)
  end
end

return M
