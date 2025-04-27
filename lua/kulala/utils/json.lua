local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

M.format = function(json_string)
  local system_arg_limit = 1000

  local jq_path = require("kulala.config").get().jq_path or "jq"
  local jq_exists = vim.fn.executable(jq_path) == 1
  if not jq_exists then return json_string, Logger.warn("jq is not installed. JSON written unformatted.") end

  local cmd, temp_file

  if #json_string > system_arg_limit then
    temp_file = os.tmpname()
    require("kulala.utils.fs").write_file(temp_file, json_string)
    cmd = { "jq", "--sort-keys", ".", temp_file }
  end

  cmd = cmd or { "jq", "--sort-keys", "-n", json_string }
  local result = Shell.run(cmd, { sync = true, err_msg = "Failed to format JSON", abort_on_stderr = true })

  if not result then return json_string end
  _ = temp_file and os.remove(temp_file)

  return result.stdout
end

M.parse = function(str, opts)
  opts = opts or { object = true, array = true }
  local verbose = opts.verbose or false

  local status, result = pcall(vim.json.decode, str, opts)
  if not status then
    _ = verbose and Logger.error("Failed to parse JSON: " .. result)
    return nil, result
  end

  return result
end

return M
