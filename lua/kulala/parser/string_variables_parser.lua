local DYNAMIC_VARS = require("kulala.parser.dynamic_vars")
local Logger = require("kulala.logger")
local REQUEST_VARIABLES = require("kulala.parser.request_variables")

---Parse the variables in a string
---@param str string -- The string to parse
---@param variables table -- The variables defined in the document
---@param env table -- The environment variables
---@param silent boolean|nil -- Whether to suppress not found variable warnings
local function parse_string_variables(str, variables, env, silent)
  local function replace_placeholder(variable_name)
    local value
    -- If the variable name contains a `$` symbol then try to parse it as a dynamic variable
    if variable_name:find("^%$") then
      local variable_value = DYNAMIC_VARS.read(variable_name)
      if variable_value then
        value = variable_value
      end
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
    return value
  end
  local result = str:gsub("{{(.-)}}", replace_placeholder)
  return result
end

return {
  parse = parse_string_variables,
}
