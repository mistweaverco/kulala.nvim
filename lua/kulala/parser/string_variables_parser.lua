local DYNAMIC_VARS = require("kulala.parser.dynamic_vars")
local Logger = require("kulala.logger")
local REQUEST_VARIABLES = require("kulala.parser.request_variables")

-- Check if a string is valid UTF-8 using pcall to catch errors
local function is_valid_utf8(str)
  local success, result = pcall(vim.fn.strdisplaywidth, str)
  return success and result ~= 0
end

-- Function to check for binary data
local function contains_binary_data(value)
  if type(value) ~= "string" then return false end

  -- If it's valid UTF-8, it's not binary
  -- This should handle chinese, japanese, korean, etc.
  if is_valid_utf8(value) then return false end

  -- Check for non-printable ASCII characters
  return value:find("[%z\1-\8\11\12\14-\31\127]") ~= nil
end

local get_var_value

---Parse the variables in a string
---@param str string -- The string to parse
---@param variables table -- The variables defined in the document
---@param env table -- The environment variables
---@param silent boolean|nil -- Whether to suppress not found variable warnings
local function parse_string_variables(str, variables, env, silent)
  if not str then return "" end

  str = tostring(str)
  if #str == 0 or contains_binary_data(str) then return str end

  -- Process the string with safe replacements
  local result = str:gsub("{{%s*(.-)%s*}}", function(var)
    return get_var_value(var, variables, env, silent)
  end)

  return result
end

---@param env table
---@param key string -- The key of type "a.b.c"
local function get_nested_variable(env, key)
  if type(env) ~= "table" then return end

  local keys = vim.split(key, "%.")
  local value = env

  for _, k in ipairs(keys) do
    if not value[k] then return end
    value = value[k]
  end

  return value
end

local parse_counter = 0

function get_var_value(variable_name, variables, env, silent)
  local value
  local max_retries = 3

  if variable_name:find("^%$") then
    value = DYNAMIC_VARS.read(variable_name)
  elseif env[variable_name] then
    value = env[variable_name]
  elseif get_nested_variable(env, variable_name) then
    value = get_nested_variable(env, variable_name)
  elseif variables[variable_name] then
    value = variables[variable_name]
  elseif REQUEST_VARIABLES.parse(variable_name) then
    value = REQUEST_VARIABLES.parse(variable_name)
  else
    value = "{{" .. variable_name .. "}}"

    local msg = "The variable " .. value .. " was not found in the document or in the environment."
    _ = not silent and parse_counter == max_retries and Logger.info(msg)
  end

  if contains_binary_data(value) then return value end

  value = tostring(value or "")

  if value:match("{{") and parse_counter < max_retries then -- parse again for recursive variables
    parse_counter = parse_counter + 1
    value = parse_string_variables(value, variables, env, silent)
  else
    parse_counter = 0
  end

  return value
end

return {
  parse = parse_string_variables,
  get_var_value = get_var_value,
}
