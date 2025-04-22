local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local INT_PROCESSING = require("kulala.internal_processing")
local Logger = require("kulala.logger")

local M = {}

local function get_match(str)
  -- there is no logical or operator in lua regex
  -- so we have to use multiple patterns to match the string
  local patterns = {
    "^([%w_]+)%.(request)%.(headers)(.*)",
    "^([%w_]+)%.(request)%.(body)%.(.*)",
    "^([%w_]+)%.(response)%.(headers)(.*)",
    "^([%w_]+)%.(response)%.(cookies)(.*)",
    "^([%w_]+)%.(response)%.(body)%.(.*)",
  }
  for _, p in ipairs(patterns) do
    local path_name, path_method, path_type, subpath = string.match(str, p)
    if path_name then return path_name, path_method, path_type, subpath end
  end
end

local function get_data(name, method)
  local response = vim.iter(DB.global_update().responses):rfind(function(response)
    return response.name == name
  end)

  return method == "request" and (response or {}).request or response
end

local function get_body_value_from_path(name, method, subpath)
  local base_table = get_data(name, method)
  if not base_table then return end

  if subpath == "*" then return base_table.body end

  local contenttype = INT_PROCESSING.get_config_contenttype(base_table.headers_tbl)

  if type(contenttype.pathresolver) == "function" then
    return contenttype.pathresolver(base_table.body, subpath)
  elseif type(contenttype.pathresolver) == "table" then
    local cmd = {}

    for k, v in pairs(contenttype.pathresolver) do
      if type(v) == "string" then v = string.gsub(v, "{{path}}", subpath) end
      cmd[k] = v
    end

    local ret = vim.system(cmd, { stdin = base_table[method].body, text = true }):wait()
    if ret.code ~= 0 then return Logger.error(("Error sourcing body contents from: %s"):format(ret.stderr)) end

    return ret.stdout
  end
end

local function get_header_value_from_path(name, method, subpath)
  local base_table = get_data(name, method)
  if not base_table then return end

  local result = base_table.headers_tbl
  local path_parts = {}

  -- Split the path into parts
  for part in string.gmatch(subpath, "[^%.%[%]\"']+") do
    table.insert(path_parts, part)
  end

  for _, key in ipairs(path_parts) do
    key = tonumber(key) or key

    if result[key] then
      result = result[key]
    else
      return -- Return nil if any part of the path is not found
    end
  end

  return type(result) == "table" and result[1] or result
end

local function get_cookies_value_from_path(name, subpath)
  local base_table = get_data(name)
  if not base_table then return end

  local result = base_table.cookies
  local path_parts = {}

  -- Split the path into parts
  for part in string.gmatch(subpath, "[^%.%[%]\"']+") do
    table.insert(path_parts, part)
  end

  for _, key in ipairs(path_parts) do
    if result[key] then
      result = result[key]
    else
      return nil -- Return nil if any part of the path is not found
    end
  end

  return result
end

M.parse = function(path)
  local path_name, path_method, path_type, path_subpath = get_match(path)

  if not (path_name and path_method and path_type and path_subpath) then return end

  if path_type == "headers" then
    return get_header_value_from_path(path_name, path_method, path_subpath)
  elseif path_type == "cookies" then
    return get_cookies_value_from_path(path_name, path_subpath)
  elseif path_type == "body" then
    return get_body_value_from_path(path_name, path_method, path_subpath)
  end

  return nil
end

return M
