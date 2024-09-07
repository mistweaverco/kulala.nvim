local Logger = require("kulala.logger")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local DB = require("kulala.db")
local CONFIG = require("kulala.config")
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
  local headers_file = FS.read_file(GLOBALS.HEADERS_FILE):gsub("\r\n", "\n")
  local lines = vim.split(headers_file, "\n")
  local headers_table = {}
  for _, header in ipairs(lines) do
    if header:find(":") ~= nil then
      local kv = vim.split(header, ":")
      local key = kv[1]
      -- the value should be everything after the first colon
      -- but we can't use slice and join because the value might contain colons
      local value = header:sub(#key + 2)
      headers_table[key] = vim.trim(value)
    end
  end
  return headers_table
end

local get_cookies_as_table = function()
  local cookies_file = FS.read_file(GLOBALS.COOKIES_JAR_FILE)
  if cookies_file == nil then
    return {}
  end
  cookies_file = cookies_file:gsub("\r\n", "\n")
  local lines = vim.split(cookies_file, "\n")
  local cookies = {}
  for _, line in ipairs(lines) do
    -- Trim leading and trailing whitespace
    line = line:gsub("^%s+", ""):gsub("%s+$", "")

    -- Skip empty lines or comment lines (except #HttpOnly_)
    if line ~= "" and (line:sub(1, 1) ~= "#" or line:find("^#HttpOnly_")) then
      -- If it's a #HttpOnly_ line, remove the #HttpOnly_ part
      if line:find("^#HttpOnly_") then
        line = line:gsub("^#HttpOnly_", "")
      end

      -- Split the line into fields based on tabs
      local fields = {}
      for field in line:gmatch("[^\t]+") do
        table.insert(fields, field)
      end

      -- The field before the last one is the key
      local key = fields[#fields - 1]

      -- Store the key-value pair in the cookies table
      cookies[key] = {
        domain = fields[1],
        flag = fields[2],
        path = fields[3],
        secure = fields[4],
        expires = fields[5],
        value = fields[7],
      }
    end
  end
  return cookies
end

local get_lower_headers_as_table = function()
  local headers = get_headers_as_table()
  local headers_table = {}
  for key, value in pairs(headers) do
    headers_table[key:lower()] = value
  end
  return headers_table
end

M.get_config_contenttype = function()
  local headers = get_lower_headers_as_table()
  if headers["content-type"] then
    local content_type = vim.split(headers["content-type"], ";")[1]
    local config = CONFIG.get().contenttypes[content_type]
    if config then
      return config
    end
  end
  return CONFIG.default_contenttype
end

M.set_env_for_named_request = function(name, body)
  local named_request = {
    response = {
      headers = get_headers_as_table(),
      body = body,
      cookies = get_cookies_as_table(),
    },
    request = {
      headers = DB.find_unique("current_request").headers,
      body = DB.find_unique("current_request").body,
    },
  }
  DB.update().env[name] = named_request
end

M.env_header_key = function(cmd)
  local headers = get_lower_headers_as_table()
  local kv = vim.split(cmd, " ")
  local header_key = kv[2]
  local variable_name = kv[1]
  local value = headers[header_key:lower()]
  if value == nil then
    vim.notify("env-header-key --> Header not found.", vim.log.levels.ERROR)
  else
    DB.update().env[variable_name] = value
  end
end

M.redirect_response_body_to_file = function(data)
  if not FS.file_exists(GLOBALS.BODY_FILE) then
    return
  end
  for _, redirect in ipairs(data) do
    local fp = FS.join_paths(FS.get_current_buffer_dir(), redirect.file)
    if FS.file_exists(fp) then
      if redirect.overwrite then
        FS.copy_file(GLOBALS.BODY_FILE, fp)
      else
        Logger.warn("File already exists and overwrite is disabled: " .. fp)
      end
    else
      FS.copy_file(GLOBALS.BODY_FILE, fp)
    end
  end
end

M.env_json_key = function(cmd, body)
  local json = vim.fn.json_decode(body)
  if json == nil then
    vim.notify("env-json-key --> JSON parsing failed.", vim.log.levels.ERROR)
  else
    local kv = vim.split(cmd, " ")
    local value = get_nested_value(json, kv[2])
    DB.update().env[kv[1]] = value
  end
end

M.prompt_var = function(metadata_value)
  local kv = vim.split(metadata_value, " ")
  local key = kv[1]
  local prompt = table.concat(kv, " ", 2)
  local value = vim.fn.input(prompt)
  if value == nil or value == "" then
    return false
  end
  DB.update().env[key] = value
  return true
end

return M
