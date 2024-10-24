local Fs = require("kulala.utils.fs")
local M = {}

M.clear_global = function(key_or_keys)
  local globals_fp = Fs.get_global_scripts_variables_file_path()
  local globals = Fs.file_exists(globals_fp) and vim.fn.json_decode(Fs.read_file(globals_fp)) or {}
  if key_or_keys == nil then
    globals = {}
  elseif type(key_or_keys) == "table" then
    for _, key in ipairs(key_or_keys) do
      globals[key] = nil
    end
  elseif type(key_or_keys) == "string" then
    globals[key_or_keys] = nil
  end
  Fs.write_file(globals_fp, vim.fn.json_encode(globals))
end

return M
