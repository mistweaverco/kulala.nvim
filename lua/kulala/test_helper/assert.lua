---@diagnostic disable: lowercase-global

local h = require("kulala.test_helper.ui")

local M = {}

local function fail(msg)
  error(msg or "assertion failed", 2)
end

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

local function tbl_same(a, b)
  if vim.deep_equal(a, b) then return true end
  return false, string.format("expected %s,\ngot %s", vim.inspect(a), vim.inspect(b))
end

M.are = {}

function M.are.equal(expected, actual)
  if actual == nil and expected ~= nil and type(expected) == "string" and type(actual) == "nil" then
    actual, expected = expected, actual
  end
  if expected ~= actual then
    fail(string.format("expected: %s\nactual: %s", vim.inspect(expected), vim.inspect(actual)))
  end
end

function M.are.same(expected, actual)
  local ok, msg = tbl_same(expected, actual)
  if not ok then fail(msg) end
end

function M.equal(expected, actual)
  M.are.equal(expected, actual)
end

function M.same(expected, actual)
  M.are.same(expected, actual)
end

function M.is_nil(value)
  if value ~= nil then fail(string.format("expected nil, got %s", vim.inspect(value))) end
end

function M.is_not_nil(value)
  if value == nil then fail("expected non-nil value") end
end

function M.is_true(value)
  if value ~= true then fail(string.format("expected true, got %s", vim.inspect(value))) end
end

function M.is_false(value)
  if value ~= false then fail(string.format("expected false, got %s", vim.inspect(value))) end
end

function M.is_truthy(value)
  if not value then fail(string.format("expected truthy value, got %s", vim.inspect(value))) end
end

function M.is_string(value)
  if type(value) ~= "string" then fail(string.format("expected string, got %s", type(value))) end
end

function M.is_same(expected, actual)
  M.are.same(expected, actual)
end

M.is_not = {}

function M.is_not.same(expected, actual)
  local ok = tbl_same(expected, actual)
  if ok then fail(string.format("expected different values, both are %s", vim.inspect(expected))) end
end

function M.matches(pattern, value)
  if type(value) ~= "string" then fail(string.format("expected string subject, got %s", type(value))) end
  if not value:match(pattern) then fail(string.format('pattern "%s" did not match value:\n%s', pattern, value)) end
end

function M.not_matches(pattern, value)
  if type(value) ~= "string" then fail(string.format("expected string subject, got %s", type(value))) end
  if value:match(pattern) then fail(string.format('pattern "%s" unexpectedly matched value:\n%s', pattern, value)) end
end

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

function M.has_string(value, pattern)
  vim.validate {
    arg_1 = { value, { "string", "table" } },
    arg_2 = { pattern, { "string", "table" } },
  }

  if type(value) == "table" then value = h.to_string(value) end
  if type(pattern) == "table" then pattern = h.to_string(pattern) end

  value = value:clean()
  pattern = pattern:clean()

  if not value:find(pattern, 1, true) then
    fail(
      string.format(
        '\n\n**Expected "%s"\n\n**to have string "%s"\n\n%s',
        value,
        pattern,
        compare_strings(value, pattern)
      )
    )
  end
end

function M.has_properties(object, properties)
  vim.validate {
    arg_1 = { object, "table" },
    arg_2 = { properties, "table" },
  }

  local missing_o, missing_p = {}, {}
  local result = true

  local key_paths = get_key_paths(properties) or {}

  for _, path in ipairs(key_paths) do
    local o_value = vim.tbl_get(object, vim.unpack(path))
    local prop_value = vim.tbl_get(properties, vim.unpack(path))

    if o_value ~= prop_value then
      result = false
      missing_p[path] = prop_value

      local parent_path = vim.deepcopy(path)
      table.remove(parent_path)
      parent_path = #parent_path == 0 and path or parent_path

      missing_o[parent_path] = vim.tbl_get(object, vim.unpack(parent_path))
    end
  end

  missing_o = vim.tbl_count(missing_o) == 0 and object or missing_o

  if not result then
    fail(
      string.format('\n\n**Expected "%s"\n\n**to have properties "%s"', vim.inspect(missing_o), vim.inspect(missing_p))
    )
  end
end

---Minimal snapshot helper for tests that mutate module tables (e.g. Fs.os).
function M.snapshot()
  local saved = {}
  return {
    revert = function()
      for tbl, keys in pairs(saved) do
        for key, value in pairs(keys) do
          tbl[key] = value
        end
      end
    end,
    save = function(tbl, key)
      saved[tbl] = saved[tbl] or {}
      if saved[tbl][key] == nil then saved[tbl][key] = tbl[key] end
    end,
  }
end

return M
