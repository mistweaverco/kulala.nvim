local Augroups = require("kulala.augroups")
local CONFIG = require("kulala.config")
local Export = require("kulala.cmd.export")
local Fmt = require("kulala.formatter.fmt")
local Fs = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local Graphql = require("kulala.graphql")
local Logger = require("kulala.logger")
local ScriptsUtils = require("kulala.parser.scripts.utils")
local UI = require("kulala.ui")

local M = {}

M.setup = function(config)
  CONFIG.setup(config)
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
  ScriptsUtils.clear_global(key_or_keys)
end

M.download_graphql_schema = function()
  Graphql.download_schema()
end

M.scratchpad = function()
  UI:scratchpad()
end

M.get_selected_env = function()
  return vim.g.kulala_selected_env or CONFIG.get().default_env
end

M.set_selected_env = function(env)
  vim.g.kulala_selected_env = env or require("kulala.ui.env_manager").open() or vim.g.kulala_selected_env
end

---Clears all cached files
---Useful when you want to clear all cached files
M.clear_cached_files = function()
  Fs.delete_cached_files()
end

---Import file to Kulala
---@param from string|nil -- "postman"|"openapi"|"bruno"|nil (postman by default)
M.import = function(from)
  Fmt.convert(from)
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
