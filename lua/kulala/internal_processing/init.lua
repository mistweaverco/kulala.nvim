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
