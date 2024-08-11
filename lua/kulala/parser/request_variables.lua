local DB = require("kulala.db")

local M = {}

local function get_match(str)
  -- there is no logical or operator in lua regex
  -- so we have to use multiple patterns to match the string
  local patterns = {
    "^([%w_]+)%.(request)%.(headers)(.*)",
    "^([%w_]+)%.(request)%.(body)%.(.*)",
    "^([%w_]+)%.(response)%.(headers)(.*)",
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

local function is_json_path(subpath)
  local p = "^%$.*"
  return string.match(subpath, p)
end

local function is_xpath_path(subpath)
  local p = "^//.*"
  return string.match(subpath, p)
end

local function get_xpath_body_value_from_path(name, method, path)
  local base_table = DB.data.env[name]
  if not base_table then
    return nil
  end
  if not base_table[method] then
    return nil
  end
  if not base_table[method].body then
    return nil
  end
  path = string.gsub(path, "^(%w+)%.(response|request)%.body%.", "")
  local body = base_table[method].body
  local cmd = { "xmllint", "--xpath", path, "-" }
  local result = vim.system(cmd, { stdin = body, text = true }):wait().stdout
  return result
end

local function get_json_body_value_from_path(name, method, subpath)
  local base_table = DB.data.env[name]
  if not base_table then
    return nil
  end
  if not base_table[method] then
    return nil
  end
  if not base_table[method].body then
    return nil
  end

  subpath = string.gsub(subpath, "^%$%.", "")

  local result = vim.fn.json_decode(base_table[method].body)

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

local function get_header_value_from_path(name, method, subpath)
  local base_table = DB.data.env[name]
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

M.parse = function(path)
  local path_name, path_method, path_type, path_subpath = get_match(path)

  if not path_name or not path_method or not path_type or not path_subpath then
    return nil
  end

  if path_type == "headers" then
    return get_header_value_from_path(path_name, path_method, path_subpath)
  elseif path_type == "body" then
    if is_json_path(path_subpath) then
      return get_json_body_value_from_path(path_name, path_method, path_subpath)
    elseif is_xpath_path(path_subpath) then
      return get_xpath_body_value_from_path(path_name, path_method, path_subpath)
    end
  end

  return nil
end

return M
