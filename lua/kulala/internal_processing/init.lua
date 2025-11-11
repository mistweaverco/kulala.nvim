local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local Json = require("kulala.utils.json")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

-- Function to access a nested key in a table dynamically
local function get_nested_value(t, key)
  local keys = vim.split(key, "%.")
  local value = t

  for _, k in ipairs(keys) do
    value = value[k]
    if not value then return end
  end

  return value
end

---Function to get the last headers as a table
---@description Reads provided headers string or the headers file and returns the headers as a table.
---In some cases the headers file might contain multiple header sections,
---e.g. if you have follow-redirections enabled.
---This function will return the headers of the last response.
---@param headers string|nil
---@return table|nil
local get_last_headers_as_table = function(headers)
  if type(headers) == "table" then return headers end

  headers = headers or FS.read_file(GLOBALS.HEADERS_FILE)
  if not headers then return end

  headers = headers:gsub("\r\n", "\n")
  local lines = vim.split(headers, "\n")
  local headers_table = {}

  -- INFO: We only want the headers of the last response
  -- so we reset the headers_table only each time the previous line was empty
  -- and we also have new headers data
  local previously_empty = false

  for _, header in ipairs(lines) do
    local empty_line = header == ""
    if empty_line then
      previously_empty = true
    else
      if previously_empty then headers_table = {} end
      previously_empty = false

      if header:find(":") then
        local kv = vim.split(header, ":")
        local key = kv[1]
        local value = header:sub(#key + 2)

        if not headers_table[key] then
          headers_table[key] = { vim.trim(value) }
        else
          table.insert(headers_table[key], vim.trim(value))
        end
      end
    end
  end
  return headers_table
end

local get_cookies_as_table = function()
  local cookies_file = FS.read_file(GLOBALS.COOKIES_JAR_FILE)
  if cookies_file == nil then return {} end
  cookies_file = cookies_file:gsub("\r\n", "\n")
  local lines = vim.split(cookies_file, "\n")
  local cookies = {}
  for _, line in ipairs(lines) do
    -- Trim leading and trailing whitespace
    line = line:gsub("^%s+", ""):gsub("%s+$", "")

    -- Skip empty lines or comment lines (except #HttpOnly_)
    if line ~= "" and (line:sub(1, 1) ~= "#" or line:find("^#HttpOnly_")) then
      -- If it's a #HttpOnly_ line, remove the #HttpOnly_ part
      if line:find("^#HttpOnly_") then line = line:gsub("^#HttpOnly_", "") end

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

local get_lower_headers_as_table = function(headers)
  headers = get_last_headers_as_table(headers) or {}
  local headers_table = {}
  for key, value in pairs(headers) do
    headers_table[key:lower()] = value
  end
  return headers_table
end

M.get_config_contenttype = function(headers, view)
  headers = get_lower_headers_as_table(headers)
  local content_type = headers["content-type"]

  if content_type then
    content_type = type(content_type) == "table" and content_type[1] or content_type
    content_type = vim.split(content_type, ";")[1]
    content_type = vim.trim(content_type)

    if view == "verbose" then
      return content_type == "kulala/grpc_error" and { ft = "kulala_grpc_error" } or { ft = "kulala_verbose_result" }
    end

    local config_key = vim.iter(CONFIG.get().contenttypes):find(function(k, _)
      return content_type:match(k)
    end)

    local config = config_key and CONFIG.get().contenttypes[config_key]

    if config and type(config) == "string" then config = CONFIG.get().contenttypes[config] end
    if config then return config end
  end

  return CONFIG.default_contenttype
end

M.env_header_key = function(cmd)
  local headers = get_lower_headers_as_table()
  local kv = vim.split(cmd, " ")
  local header_key = kv[2]
  local variable_name = kv[1]
  local value = headers[header_key:lower()]

  if not value then return Logger.error("env-header-key --> Header not found") end
  DB.update().env[variable_name] = value
end

local function format_json_response(fp)
  local formatter = CONFIG.get().contenttypes["application/json"].formatter
  if not formatter then return end

  local cmd = { "sh", "-c", table.concat(formatter, " ") .. " '" .. GLOBALS.BODY_FILE .. "' " .. " > '" .. fp .. "'" }

  Shell.run(cmd, {
    err_msg = "Failed to format json while redirecting to " .. fp,
    abort_on_stderr = true,
  }, function()
    Logger.info("Formatted JSON response in: " .. fp)
  end)
end

M.redirect_response_body_to_file = function(data)
  if not FS.file_exists(GLOBALS.BODY_FILE) then return end

  for _, redirect in ipairs(data) do
    local fp = FS.get_file_path(redirect.file)

    if FS.file_exists(fp) and not redirect.overwrite then
      return Logger.warn("File already exists,  use `>>!` to overwrite: " .. fp)
    else
      FS.copy_file(GLOBALS.BODY_FILE, fp)
    end

    if vim.fn.fnamemodify(fp, ":e") == "json" and CONFIG.get().format_json_on_redirect then format_json_response(fp) end
  end
end

M.env_json_key = function(cmd, response)
  local json = Json.parse(response.body)
  if not json then return Logger.error("env-json-key --> JSON parsing failed.") end

  local kv = vim.split(cmd, " ")
  local value = get_nested_value(json, kv[2])
  DB.update().env[kv[1]] = value
end

M.prompt_var = function(metadata_value, secret)
  local input = secret and vim.fn.inputsecret or vim.fn.input
  local kv = vim.split(metadata_value, " ")

  local var_name = kv[1]
  local prompt = table.concat(kv, " ", 2)
  prompt = prompt == "" and "Enter value for variable [" .. var_name .. "]: " or prompt

  local status, value = pcall(input, prompt)
  if not status or not value or value == "" then return false end

  DB.update().env[var_name] = value
  return true
end

M.delay = function(ms)
  vim.wait(ms)
end

M.get_cookies = get_cookies_as_table
M.get_headers = get_last_headers_as_table

return M
