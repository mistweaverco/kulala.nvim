local DYNAMIC_VARS = require("kulala.parser.dynamic_vars")
local Logger = require("kulala.logger")
local REQUEST_VARIABLES = require("kulala.parser.request_variables")

-- Check if a string is valid UTF-8 using pcall to catch errors
local function is_valid_utf8(str)
  local success, _ = pcall(vim.fn.strdisplaywidth, str)
  return success
end

-- Function to check for binary data
local function contains_binary_data(value)
  if type(value) ~= "string" then
    return false
  end

  -- If it's valid UTF-8, it's not binary
  -- This should handle chinese, japanese, korean, etc.
  if is_valid_utf8(value) then
    return false
  end

  -- Check for non-printable ASCII characters
  return value:find("[%z\1-\8\11\12\14-\31\127]") ~= nil
end

---Parse the variables in a string
---@param str string -- The string to parse
---@param variables table -- The variables defined in the document
---@param env table -- The environment variables
---@param silent boolean|nil -- Whether to suppress not found variable warnings
local function parse_string_variables(str, variables, env, silent)
  -- Early check: if the input string is a blob (represented as userdata in Neovim)
  if contains_binary_data(str) then
    return str
  end

  local function replace_placeholder(variable_name)
    local value

    -- Check each source for the variable
    if variable_name:find("^%$") then
      value = DYNAMIC_VARS.read(variable_name)
    elseif variables[variable_name] then
      value = parse_string_variables(variables[variable_name], variables, env)
    elseif env[variable_name] then
      value = env[variable_name]
    elseif REQUEST_VARIABLES.parse(variable_name) then
      value = REQUEST_VARIABLES.parse(variable_name)
    else
      value = "{{" .. variable_name .. "}}"
      if not silent then
        Logger.info(
          "The variable '"
            .. variable_name
            .. "' was not found in the document or in the environment. Returning the string as received ..."
        )
      end
    end

    -- Early check if the variable value is a blob (userdata)
    if contains_binary_data(value) then
      return value
    end

    -- Safe conversion to string
    return tostring(value or "")
  end

  -- Process the string with safe replacements
  local result = str:gsub("{{(.-)}}", replace_placeholder)
  return result
end

return {
  parse = parse_string_variables,
}
