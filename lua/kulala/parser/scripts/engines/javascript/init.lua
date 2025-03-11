local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local Logger = require("kulala.logger")
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
local BASE_FILE_VER = FS.join_paths(SCRIPTS_BUILD_DIR, "dist", ".version")
local BASE_FILE_PRE = FS.join_paths(SCRIPTS_BUILD_DIR, "dist", "pre_request.js")
local BASE_FILE_POST_CLIENT_ONLY = FS.join_paths(SCRIPTS_BUILD_DIR, "dist", "post_request_client_only.js")
local BASE_FILE_POST = FS.join_paths(SCRIPTS_BUILD_DIR, "dist", "post_request.js")
local FILE_MAPPING = {
  pre_request_client_only = BASE_FILE_PRE_CLIENT_ONLY,
  pre_request = BASE_FILE_PRE,
  post_request_client_only = BASE_FILE_POST_CLIENT_ONLY,
  post_request = BASE_FILE_POST,
}

local is_uptodate = function()
  local version = FS.read_file(BASE_FILE_VER) or 0
  return GLOBALS.VERSION == version and FS.file_exists(BASE_FILE_PRE) and FS.file_exists(BASE_FILE_POST)
end

---@param wait boolean -- wait to complete
M.install_dependencies = function(wait)
  if is_uptodate() then return true end

  Logger.warn("Javascript base files not found or are out of date.")
  Logger.info(
    "Installing Javascript dependencies...\nPlease wait until the installation is complete and rerun requests."
  )

  local cmd_install, cmd_build
  local log_info, log_err = vim.schedule_wrap(Logger.info), vim.schedule_wrap(Logger.error)

  FS.copy_dir(BASE_DIR, SCRIPTS_BUILD_DIR)

  cmd_install = vim.system({ NPM_BIN, "install", "--prefix", SCRIPTS_BUILD_DIR }, { text = true }, function(out)
    if out.code ~= 0 then log_err("npm install fail with code " .. out.code .. out.stderr) end

    cmd_build = vim.system({ NPM_BIN, "run", "build", "--prefix", SCRIPTS_BUILD_DIR }, { text = true }, function(out)
      if out.code ~= 0 then return log_err("npm run build fail with code " .. out.code .. out.stderr) end

      FS.write_file(BASE_FILE_VER, GLOBALS.VERSION)
      log_info("Javascript dependencies installed.")
    end)
  end)

  _ = wait and cmd_install:wait()
  _ = wait and cmd_build:wait()

  return false
end

---@param script_type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request"
---type of script
---@param is_external_file boolean -- is external file
---@param script_data string[]|string -- either list of inline scripts or path to script file
---@return string|nil, string|nil
local generate_one = function(script_type, is_external_file, script_data)
  local userscript
  local base_file_path = FILE_MAPPING[script_type]

  if base_file_path == nil then return nil, nil end

  local base_file = FS.read_file(base_file_path)
  if base_file == nil then return nil, nil end

  local script_cwd
  local buf_dir = FS.get_current_buffer_dir()

  if is_external_file then
    -- if script_data starts with ./ or ../, it is a relative path
    if string.match(script_data, "^%./") or string.match(script_data, "^%../") then
      local local_script_path = script_data:gsub("^%./", "")
      script_data = FS.join_paths(buf_dir, local_script_path)
    end

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

  FS.write_file(script_path, base_file, false)

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
  local script_path, script_cwd = generate_one(script_type, false, scripts_data.inline)

  if script_path and script_cwd then table.insert(scripts, { path = script_path, cwd = script_cwd }) end

  for _, script_data in ipairs(scripts_data.files) do
    script_path, script_cwd = generate_one(script_type, true, script_data)
    if script_path and script_cwd then table.insert(scripts, { path = script_path, cwd = script_cwd }) end
  end

  return scripts
end

local scripts_is_empty = function(scripts_data)
  return #scripts_data.inline == 0 and #scripts_data.files == 0
end

---@param type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request" -- type of script
---@param data ScriptData
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
    local output = vim
      .system({ NODE_BIN, script.path }, { cwd = script.cwd, env = { NODE_PATH = FS.join_paths(script.cwd, "node_modules") } })
      :wait()

    if output.stderr and not output.stderr:match("^%s*$") then
      if not disable_output then Logger.error(("Errors while running JS script: %s"):format(output.stderr)) end
      FS.write_file(files[type], output.stderr)
    end

    if output.stdout and not output.stdout:match("^%s*$") then
      _ = not disable_output and Logger.log("JS: " .. output.stdout)
      if not FS.write_file(files[type], output.stdout) then return Logger.error("write " .. files[type] .. " fail") end
    end
  end

  return true
end

return M
