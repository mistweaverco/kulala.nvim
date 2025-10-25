local Json = require("kulala.utils.json")

local M = {}

---@param body string|table
M.parse = function(body, path)
  local subpath = string.gsub(path, "^%$%.*", "")

  local result = type(body) == "string" and Json.parse(body) or body
  if not result then return end

  local path_parts = {}

  for part in string.gmatch(subpath, "[^%.%[%]\"']+") do
    table.insert(path_parts, part)
  end

  for _, key in ipairs(path_parts) do
    -- Check if the current result is a table (either an object or an array)
    if type(result) == "table" then
      -- If the key is a number (index), convert it to an integer and access the array element
      local index = tonumber(key)
      if index then
        -- Lua arrays are 1-based, so we need to adjust the index
        if result[index + 1] then
          result = result[index + 1]
        else
          return nil -- Return nil if the index is out of bounds
        end
      else
        -- Otherwise, assume it's a key in an object
        if result[key] then
          result = result[key]
        else
          return nil -- Return nil if the key is not found
        end
      end
    else
      return nil -- Return nil if result is not a table at this point
    end
  end

  return result
end

return M
