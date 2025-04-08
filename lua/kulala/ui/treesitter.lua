local Fs = require("kulala.utils.fs")
local M = {}

M.set = function()
  local query_path = Fs.get_plugin_root_dir() .. "/queries/injections.scm"
  local query = Fs.read_file(query_path)
  vim.treesitter.query.set("http", "injections", query)
end

return M
