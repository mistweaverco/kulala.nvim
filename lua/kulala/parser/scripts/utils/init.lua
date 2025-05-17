local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")

local M = {}

M.clear_global = function(key_or_keys)
  local globals_fp = Fs.get_global_scripts_variables_file_path()
  local globals = Fs.read_json(globals_fp) or {}

  if not key_or_keys then
    globals = {}
  elseif type(key_or_keys) == "table" then
    for _, key in ipairs(key_or_keys) do
      globals[key] = nil
    end
  elseif type(key_or_keys) == "string" then
    globals[key_or_keys] = nil
  end

  Fs.write_json(globals_fp, globals)
  Logger.info("Cleared global variables: " .. (key_or_keys or "all"))
end

return M
