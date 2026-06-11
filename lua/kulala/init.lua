local Augroups = require("kulala.augroups")
local Backend = require("kulala.backend")
local CONFIG = require("kulala.config")
local Export = require("kulala.cmd.export")
local Fs = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local Graphql = require("kulala.graphql")
local KulalaCore = require("kulala.cmd.kulala_core_bridge")
local Logger = require("kulala.logger")
local UI = require("kulala.ui")

local M = {}

M.setup = function(config)
  CONFIG.setup(config)
  local kulala_core_path = CONFIG.get().kulala_core.path
  if kulala_core_path == nil or not Fs.file_exists(kulala_core_path) then
    Backend.ensure_installed()
    return
  end
  Augroups.setup()
end

M.open = function()
  UI:open_default_view()
end

M.run = function()
  UI:open()
end

M.run_all = function()
  UI:open_all()
end

M.replay = function()
  UI:replay()
end

M.inspect = function()
  UI:inspect()
end

M.open_cookies_jar = function()
  vim.cmd("edit " .. GLOBALS.COOKIES_JAR_FILE)
end

M.copy = function()
  UI:copy()
end

M.show_stats = function()
  UI:show_stats()
end

M.from_curl = function()
  UI:from_curl()
end

M.version = function()
  local neovim_version = vim.fn.execute("version") or "Unknown"
  Logger.info("Kulala version: " .. GLOBALS.VERSION .. "\n\n" .. "Neovim version: " .. neovim_version)
end

M.jump_next = function()
  UI:jump_next()
end

M.jump_prev = function()
  UI:jump_prev()
end

M.toggle_view = function()
  UI:toggle_headers()
end

M.close = function()
  UI:close()
end

M.search = function()
  require("kulala.ui.request_manager").open()
end

M.scripts_clear_global = function(key_or_keys)
  local ok, err = KulalaCore.clear_globals(key_or_keys)
  if not ok then
    Logger.error(err or "Failed to clear global script variables", 1, { report = true })
    return
  end
  local label = key_or_keys
  if type(key_or_keys) == "table" then label = table.concat(key_or_keys, ", ") end
  Logger.info("Cleared global variables: " .. (label or "all"))
end

M.download_graphql_schema = function()
  Graphql.download_schema()
end

M.clear_graphql_schema_cache = function(host)
  Graphql.clear_schema_cache(host)
end

M.scratchpad = function()
  UI:scratchpad()
end

M.get_selected_env = function()
  return vim.g.kulala_selected_env or CONFIG.get().default_env
end

M.set_selected_env = function(env)
  if type(env) == "string" and env ~= "" then
    vim.g.kulala_selected_env = env
    require("kulala.db").update().selected_env = env
    return env
  end
  require("kulala.ui.env_manager").open()
  return M.get_selected_env()
end

---Clears all cached files
---Useful when you want to clear all cached files
M.clear_cached_files = function()
  Fs.delete_cached_files()
end

--- Exports current buffer|file|folder to Postman collection
---@param path string|nil Path to the file or folder to export. If nil, exports the current buffer.
M.export = function(path)
  Export.export_requests(path)
end

--- Generate a bug report and open a GitHub issue with it
M.generate_bug_report = function()
  require("kulala.logger.bug_report").generate_bug_report()
end

return M
