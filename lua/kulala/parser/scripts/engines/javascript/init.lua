local Async = require("kulala.utils.async")
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local FS = require("kulala.utils.fs")
local Float = require("kulala.ui.float")
local GLOBALS = require("kulala.globals")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

local NPM_EXISTS = vim.fn.executable("npm") == 1
local NODE_EXISTS = vim.fn.executable("node") == 1

local NPM_BIN = vim.fn.exepath("npm")
local NODE_BIN = vim.fn.exepath("node")

local SCRIPTS_DIR = FS.get_scripts_dir()
local REQUEST_SCRIPTS_DIR = FS.get_request_scripts_dir()
local SCRIPTS_BUILD_DIR = FS.get_tmp_scripts_build_dir()

local BASE_DIR = FS.join_paths(SCRIPTS_DIR, "engines", "javascript", "lib")
local BASE_FILE_PRE_CLIENT_ONLY = FS.join_paths(SCRIPTS_BUILD_DIR, "dist", "pre_request_client_only.js")
local BASE_FILE_PRE = FS.join_paths(SCRIPTS_BUILD_DIR, "dist", "pre_request.js")
local BASE_FILE_POST_CLIENT_ONLY = FS.join_paths(SCRIPTS_BUILD_DIR, "dist", "post_request_client_only.js")
local BASE_FILE_POST = FS.join_paths(SCRIPTS_BUILD_DIR, "dist", "post_request.js")

local FILE_MAPPING = {
  pre_request_client_only = BASE_FILE_PRE_CLIENT_ONLY,
  pre_request = BASE_FILE_PRE,
  post_request_client_only = BASE_FILE_POST_CLIENT_ONLY,
  post_request = BASE_FILE_POST,
}

local function get_build_ver()
  local package = FS.read_json(BASE_DIR .. "/package.json")
  return package and package.version or ""
end

local is_uptodate = function()
  DB.session.js_build_ver_repo = DB.session.js_build_ver_repo or get_build_ver()

  return DB.settings.js_build_ver_local == DB.session.js_build_ver_repo
    and FS.file_exists(BASE_FILE_PRE)
    and FS.file_exists(BASE_FILE_POST)
end

---@param wait boolean|nil -- wait to complete
M.install_dependencies = function(wait)
  if is_uptodate() then return true end
  if vim.g.kulala_js_installing then return false end

  local cmd = require("kulala.cmd")
  vim.g.kulala_js_installing = true

  Logger.info("Javascript dependencies not found or are out of date.")
  local progress = Float.create_progress_float("Installing JS dependencies...")

  _ = not wait and cmd.queue:pause()

  local co, cmd_install, cmd_build
  co = coroutine.create(function()
    FS.copy_dir(BASE_DIR, SCRIPTS_BUILD_DIR)

    cmd_install = Shell.run(
      { NPM_BIN, "clean-install", "--prefix", SCRIPTS_BUILD_DIR },
      { err_msg = "JS dependencies install failed: ", on_error = progress.hide },
      function()
        Async.co_resume(co)
      end
    )
    Async.co_yield(co)

    cmd_build = Shell.run(
      { NPM_BIN, "run", "build", "--prefix", SCRIPTS_BUILD_DIR },
      { err_msg = "JS dependencies build failed: ", on_error = progress.hide },
      function()
        Async.co_resume(co)
      end
    )
    Async.co_yield(co)

    Async.co_wrap(co, function()
      DB.settings:write { js_build_ver_local = DB.session.js_build_ver_repo }
      vim.g.kulala_js_installing = false
    end)

    progress.hide()
    Logger.info("Javascript dependencies installed")

    _ = not wait and cmd.queue:resume()
  end)

  Async.co_resume(co)

  _ = wait and cmd_install and cmd_install:wait()
  if not cmd_build then return false end

  _ = wait and cmd_build:wait()

  return false
end

---@param script_type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request"
---@param is_external_file boolean -- is external file
---@param script_data string[]|string -- either list of inline scripts or path to script file
---@return string|nil, string|nil
local generate_one = function(script_type, is_external_file, script_data)
  local userscript

  local base_file_path = FILE_MAPPING[script_type]
  if not base_file_path then return end

  local base_file = FS.read_file(base_file_path)
  if not base_file then return end

  local script_cwd
  local buf_dir = FS.get_current_buffer_dir()

  if is_external_file then
    if FS.file_exists(script_data) then
      script_cwd = FS.get_dir_by_filepath(script_data)
      userscript = FS.read_file(script_data)
    else
      Logger.error(("Could not read the %s script: %s"):format(script_type, script_data))
      userscript = ""
    end
  end

  script_cwd = script_cwd or buf_dir
  userscript = userscript or vim.fn.join(script_data, "\n")
  base_file = base_file .. "\n" .. userscript

  local uuid = FS.get_uuid()
  local script_path = FS.join_paths(REQUEST_SCRIPTS_DIR, uuid .. ".js")

  FS.write_file(script_path, base_file)

  return script_path, script_cwd
end

---@class JsScripts
---@field path string -- path to script
---@field cwd string -- current working directory

---@param script_type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request" -- type of script
---@param scripts_data ScriptData -- data for scripts
---@return JsScripts<table> -- paths to scripts
local generate_all = function(script_type, scripts_data)
  local scripts = {}
  local script_path, script_cwd

  for _, script_data in ipairs(scripts_data.files) do
    script_path, script_cwd = generate_one(script_type, true, script_data)
    if script_path and script_cwd then table.insert(scripts, { path = script_path, cwd = script_cwd }) end
  end

  script_path, script_cwd = generate_one(script_type, false, scripts_data.inline)

  local pos = scripts_data.priority == "inline" and 1 or (#scripts + 1)
  if script_path and script_cwd then table.insert(scripts, pos, { path = script_path, cwd = script_cwd }) end

  return scripts
end

local scripts_is_empty = function(scripts_data)
  return #scripts_data.inline == 0 and #scripts_data.files == 0
end

local function default_node_path_resolver(_, script_file_dir, _)
  local path =
    vim.fs.find({ "node_modules" }, { path = script_file_dir, limit = 1, type = "directory", upward = true })[1]
  return path or FS.join_paths(script_file_dir, "node_modules")
end

---@param type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request" -- type of script
---@param data ScriptData
---@return boolean|nil status
M.run = function(type, data)
  local files = { ["pre_request"] = GLOBALS.SCRIPT_PRE_OUTPUT_FILE, ["post_request"] = GLOBALS.SCRIPT_POST_OUTPUT_FILE }
  local disable_output = CONFIG.get().disable_script_print_output

  if scripts_is_empty(data) then return end
  if not NODE_EXISTS then return Logger.error("node not found, please install nodejs") end
  if not NPM_EXISTS then return Logger.error("npm not found, please install nodejs") end

  if not M.install_dependencies() then return end

  local scripts = generate_all(type, data)
  if #scripts == 0 then return end

  for _, script in ipairs(scripts) do
    local buf_dir = FS.get_current_buffer_dir()
    local node_path_resolver = CONFIG.get().scripts.node_path_resolver or default_node_path_resolver

    local output = vim
      .system(
        { NODE_BIN, script.path },
        { cwd = script.cwd, env = { NODE_PATH = node_path_resolver(buf_dir, script.cwd, data) } }
      )
      :wait()

    if output.stderr and not output.stderr:match("^%s*$") then
      if not disable_output then Logger.error(("Errors while running JS script: %s"):format(output.stderr)) end
      FS.write_file(files[type], output.stderr)
    end

    if output.stdout and not output.stdout:match("^%s*$") then
      _ = not disable_output and Logger.info(output.stdout, { title = "Kulala JS Script Output" })
      if not FS.write_file(files[type], output.stdout) then return Logger.error("write " .. files[type] .. " fail") end
    end
  end

  return true
end

return M
