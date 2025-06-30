local Logger = require("kulala.logger")

local M = {}

---Parse a JSON string into a Lua table
---@param str string
---@param opts? table<{ verbose: boolean, luanil: table<{object: boolean, array: boolean }> }> -- verbose: log errors
---@param filename? string -- used for logging errors
---@return table|nil, string|nil
M.parse = function(str, opts, filename)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    verbose = false,
    luanil = { object = true, array = true },
  })

  local status, result = pcall(vim.json.decode, str or "", opts)
  if not status then
    _ = opts.verbose and Logger.error(("Failed to parse %s: %s"):format(filename or "JSON", result))
    return nil, result
  end

  return result
end

local function sort_table(t)
  local sorted = {}
  for k, v in pairs(t) do
    table.insert(sorted, { k, v })
  end

  table.sort(sorted, function(a, b)
    return a[1] < b[1]
  end)

  return sorted
end

M.encode = function(obj, opts)
  opts = opts or {}

  if not (opts.sort and type(obj) == "table" and not vim.islist(obj)) then return vim.json.encode(obj, opts) end
  local sorted_obj = sort_table(obj)

  return "{"
    .. table.concat(
      vim.tbl_map(function(kv)
        return string.format("%q: %s", kv[1], M.encode(kv[2], opts))
      end, sorted_obj),
      ", "
    )
    .. "}"
end

return M
