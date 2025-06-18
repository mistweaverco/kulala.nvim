local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

M.format = function(json_string, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    verbose = true,
    sort = true,
  })

  json_string = type(json_string) == "table" and vim.json.encode(json_string, opts) or json_string

  local system_arg_limit = 1000

  local jq_path = require("kulala.config").get().contenttypes["application/json"]
  jq_path = jq_path and jq_path.formatter and jq_path.formatter[1] or vim.fn.exepath("jq")

  if vim.fn.executable(jq_path) == 0 then
    _ = opts.versbose and Logger.warn("jq is not installed. JSON written unformatted.")
    return json_string
  end

  local cmd = { jq_path }
  _ = opts.sort and table.insert(cmd, "--sort-keys")

  local temp_file
  if #json_string > system_arg_limit then
    temp_file = os.tmpname()
    require("kulala.utils.fs").write_file(temp_file, json_string)

    table.insert(cmd, temp_file)
  else
    vim.list_extend(cmd, { "-n", json_string })
  end

  local result = Shell.run(cmd, { sync = true, err_msg = "Failed to format JSON", abort_on_stderr = true })

  _ = temp_file and os.remove(temp_file)
  if not result or result.code ~= 0 or result.stderr ~= "" or result.stdout == "" then return json_string end

  return result.stdout
end

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
