local assert = require("luassert.assert")
local h = require("test_helper.ui")

local M = {}

local function compare_strings(str_1, str_2)
  local char_1, char_2, pos
  for i = 1, #str_1 do
    pos, char_1, char_2 = i, str_1:sub(i, i), str_2:sub(i, i)
    if char_1 ~= char_2 then break end
  end

  if not pos then return "" end
  pos = pos + 1

  local sub_1 = str_1:sub(pos - 5, pos - 1) .. "<< " .. str_1:sub(pos, pos) .. " >>" .. str_1:sub(pos + 1, pos + 5)
  local sub_2 = str_2:sub(pos - 5, pos - 1) .. "<< " .. str_2:sub(pos, pos) .. " >>" .. str_2:sub(pos + 1, pos + 5)

  return ("Mismatch in pos %s\n%s\n\n%s"):format(pos, sub_1, sub_2)
end

---Asserts if object contains a string
---@param state table
---@param args table { table|string, string }
---@return boolean
local has_string = function(state, args)
  vim.validate({
    arg_1 = { args[1], { "string", "table" } },
    arg_2 = { args[2], { "string", "table" } },
  })

  local mod = state.mod
  local o, pattern = args[1], args[2]
  local result

  if type(o) == "table" then o = h.to_string(o) end
  if type(pattern) == "table" then pattern = h.to_string(pattern) end

  o = o:clean()
  pattern = pattern:clean()

  result = o:find(pattern, 1, true) and true or false

  if not (mod and result) then
    local _not = mod and "" or " not "
    local mismatch = compare_strings(o, pattern)
    state.failure_message =
      string.format('\n\n**Expected "%s"\n\n**%sto have string "%s\n\n%s"', o, _not, pattern, mismatch)
  end

  return result
end

assert:register("assertion", "has_string", has_string, "", "")

---Collects paths for nested keys
local get_key_paths
get_key_paths = function(tbl, path, paths)
  path = path or {}
  paths = paths or {}

  if type(tbl) ~= "table" then return end

  for k, v in pairs(tbl) do
    local nested_path = vim.list_extend({ path }, { k })

    if not get_key_paths(v, nested_path, paths) then table.insert(paths, vim.fn.flatten(nested_path)) end
  end
  return paths
end

---Checks if an object contains properties with values
---@param state table
---@param args table { table, table { property_name = value } }
local has_properties = function(state, args)
  vim.validate({
    arg_1 = { args[1], "table" },
    arg_2 = { args[2], "table" },
  })

  local mod = state.mod
  local o, properties = args[1], args[2]
  local missing_o, missing_p = {}, {}
  local result = true

  local key_paths = get_key_paths(properties) or {}

  for _, path in ipairs(key_paths) do
    local o_value = vim.tbl_get(o, unpack(path))
    local prop_value = vim.tbl_get(properties, unpack(path))

    if o_value ~= prop_value then
      result = false
      missing_p[path] = prop_value

      local parent_path = vim.deepcopy(path)
      table.remove(parent_path)
      parent_path = #parent_path == 0 and path or parent_path

      missing_o[parent_path] = vim.tbl_get(o, unpack(parent_path))
    end
  end

  missing_o = vim.tbl_count(missing_o) == 0 and o or missing_o

  if not (mod and result) then
    local _not = mod and "" or " not "
    state.failure_message = string.format(
      '\n\n**Expected "%s"\n\n**%sto have properties "%s"',
      vim.inspect(missing_o),
      _not,
      vim.inspect(missing_p)
    )
  end

  return result
end

assert:register("assertion", "has_properties", has_properties, "", "")

return M
