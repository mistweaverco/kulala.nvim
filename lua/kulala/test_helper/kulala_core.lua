local M = {}

---@return string|nil
function M.resolve_path()
  local candidates = {}
  local from_env = vim.env.KULALA_CORE_PATH
  if type(from_env) == "string" and from_env ~= "" then table.insert(candidates, from_env) end

  local ok, backend = pcall(require, "kulala.backend")
  if ok then
    local bin_path = backend.get_bin_path()
    if bin_path and vim.fn.executable(bin_path) == 1 then table.insert(candidates, bin_path) end
  end

  for _, path in ipairs(candidates) do
    if vim.fn.executable(path) == 1 then return vim.fn.exepath(path) end
  end
end

---Merge `kulala_core.path` into a config table used with `CONFIG.setup`.
---@param config table|nil
---@return table
function M.config(config)
  config = config or {}
  local path = M.resolve_path()
  if path then config.kulala_core = vim.tbl_extend("force", { path = path }, config.kulala_core or {}) end
  return config
end

return M
