local DB = require("kulala.db")
local CONFIG = require("kulala.config")

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
    if path_name then
      return path_name, path_method, path_type, subpath
    end
  end
  return nil, nil, nil, nil
end

local get_lower_headers = function(headers)
  local headers_table = {}
  for key, value in pairs(headers) do
    headers_table[key:lower()] = value
  end
  return headers_table
end

local function get_config_contenttype(headers)
  headers = get_lower_headers(headers)
  if headers["content-type"] then
    local content_type = vim.split(headers["content-type"], ";")[1]
    local config = CONFIG.get().contenttypes[content_type]
    if config then
      return config
    end
  end
  return CONFIG.default_contenttype
end

local function get_body_value_from_path(name, method, subpath)
  local base_table = DB.find_unique("env")[name]
  if not base_table then
    return nil
  end
  if not base_table[method] then
    return nil
  end
  if not base_table[method].body then
    return nil
  end

  if subpath == "*" then
    return base_table[method].body
  end

  if not base_table[method].headers then
    return nil
  end
  local contenttype = get_config_contenttype(base_table[method].headers)

  if type(contenttype.pathresolver) == "function" then
    return contenttype.pathresolver(base_table[method].body, subpath)
  elseif type(contenttype.pathresolver) == "table" then
    local cmd = {}
    for k, v in pairs(contenttype.pathresolver) do
      if type(v) == "string" then
        v = string.gsub(v, "{{path}}", subpath)
      end
      cmd[k] = v
    end
    return vim.system(cmd, { stdin = base_table[method].body, text = true }):wait().stdout
  end

  return nil
end

local function get_header_value_from_path(name, method, subpath)
  local base_table = DB.find_unique("env")[name]
  if not base_table then
    return nil
  end
  if not base_table[method] then
    return nil
  end
  if not base_table[method].headers then
    return nil
  end
  local result = base_table[method].headers
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

local function get_cookies_value_from_path(name, subpath)
  local db_env = DB.find_unique("env")
  local base_table = db_env and db_env[name] or nil
  if not base_table then
    return nil
  end
  if not base_table.response then
    return nil
  end
  if not base_table.response.cookies then
    return nil
  end
  local result = base_table.response.cookies
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

  if not path_name or not path_method or not path_type or not path_subpath then
    return nil
  end

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
