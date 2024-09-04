local health = vim.health
local start = health.start
local ok = health.ok
local error = health.error
local is_win = vim.api.nvim_call_function("has", { "win32" }) == 1

local M = {}

M.check = function()
  start("Checking external dependencies")
  local deps = { "curl", "jq", "xmllint" }
  for _, dep in pairs(deps) do
    if is_win then
      dep = dep .. ".exe"
    end
    local found = (vim.fn.executable(dep) == 1)
    if found then
      ok(string.format("Found %s", dep))
    else
      error(string.format("Missing %s", dep))
    end
  end
end

return M
