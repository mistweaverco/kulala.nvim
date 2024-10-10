local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local Logger = require("kulala.logger")
local M = {}

local NPM_EXISTS = vim.fn.executable("npm") == 1
local NODE_EXISTS = vim.fn.executable("node") == 1
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

M.install = function()
  FS.copy_dir(BASE_DIR, SCRIPTS_BUILD_DIR)
  vim.system({ "npm", "install", "--prefix", SCRIPTS_BUILD_DIR }):wait()
  vim.system({ "npm", "run", "build", "--prefix", SCRIPTS_BUILD_DIR }):wait()
end

---@class Scripts
---@field path string -- path to script
---@field cwd string -- current working directory

---@class ScriptData table -- data for script
---@field inline string<table> -- inline scripts
---@field files string<table> -- paths to script files

---@param script_type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request"
---type of script
---@param is_external_file boolean -- is external file
---@param script_data string<table> | string -- either inline script or path to script file
local generate_one = function(script_type, is_external_file, script_data)
  local userscript
  local base_file_path = FILE_MAPPING[script_type]
  if base_file_path == nil then
    return nil, nil
  end
  local base_file = FS.read_file(base_file_path)
  if base_file == nil then
    return nil, nil
  end
  local script_cwd
  -- buf_dir is "kulala:" when the buffer is scratch buffer
  -- in this case, use current working directory for script_cwd and base_dir
  local buf_dir = FS.get_current_buffer_dir()

  if is_external_file then
    -- if script_data starts with ./ or ../, it is a relative path
    if string.match(script_data, "^%./") or string.match(script_data, "^%../") then
      local local_script_path = script_data:gsub("^%./", "")
      local base_dir = buf_dir == "kulala:" and vim.loop.cwd() or buf_dir
      script_data = FS.join_paths(base_dir, local_script_path)
    end
    script_cwd = buf_dir == "kulala:" and vim.loop.cwd() or FS.get_dir_by_filepath(script_data)
    userscript = FS.read_file(script_data)
  else
    script_cwd = buf_dir == "kulala:" and vim.loop.cwd() or buf_dir
    userscript = vim.fn.join(script_data, "\n")
  end
  base_file = base_file .. "\n" .. userscript
  local uuid = FS.get_uuid()
  local script_path = FS.join_paths(REQUEST_SCRIPTS_DIR, uuid .. ".js")
  FS.write_file(script_path, base_file, false)
  return script_path, script_cwd
end

---@param script_type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request"
---type of script
---@param scripts_data ScriptData -- data for scripts
---@return Scripts<table> -- paths to scripts
local generate_all = function(script_type, scripts_data)
  local scripts = {}
  local script_path, script_cwd = generate_one(script_type, false, scripts_data.inline)
  if script_path ~= nil and script_cwd ~= nil then
    table.insert(scripts, { path = script_path, cwd = script_cwd })
  end
  for _, script_data in ipairs(scripts_data.files) do
    script_path, script_cwd = generate_one(script_type, true, script_data)
    if script_path ~= nil and script_cwd ~= nil then
      table.insert(scripts, { path = script_path, cwd = script_cwd })
    end
  end
  return scripts
end

local scripts_is_empty = function(scripts_data)
  return #scripts_data.inline == 0 and #scripts_data.files == 0
end

---@param type "pre_request_client_only" | "pre_request" | "post_request_client_only" | "post_request" -- type of script
---@param data ScriptData
M.run = function(type, data)
  if scripts_is_empty(data) then
    return
  end

  if not NODE_EXISTS then
    Logger.error("node not found, please install nodejs")
    return
  end

  if not NPM_EXISTS then
    Logger.error("npm not found, please install nodejs")
    return
  end

  if not FS.file_exists(BASE_FILE_PRE) or not FS.file_exists(BASE_FILE_POST) then
    Logger.warn("Javascript base files not found. Installing dependencies...")
    M.install()
  end

  local scripts = generate_all(type, data)
  if #scripts == 0 then
    return
  end

  for _, script in ipairs(scripts) do
    local output = vim
      .system({
        "node",
        script.path,
      }, {
        cwd = script.cwd,
        env = {
          NODE_PATH = FS.join_paths(script.cwd, "node_modules"),
        },
      })
      :wait()
    if output ~= nil then
      FS.delete_file(GLOBALS.SCRIPT_PRE_OUTPUT_FILE)
      FS.delete_file(GLOBALS.SCRIPT_POST_OUTPUT_FILE)

      if output.stderr ~= nil and not string.match(output.stderr, "^%s*$") then
        if not CONFIG.get().disable_script_print_output then
          vim.print(output.stderr)
        end
        if type == "pre_request" then
          FS.write_file(GLOBALS.SCRIPT_PRE_OUTPUT_FILE, output.stderr)
        elseif type == "post_request" then
          FS.write_file(GLOBALS.SCRIPT_POST_OUTPUT_FILE, output.stderr)
        end
      end
      if output.stdout ~= nil and not string.match(output.stdout, "^%s*$") then
        if not CONFIG.get().disable_script_print_output then
          vim.print(output.stdout)
        end
        if type == "pre_request" then
          if not FS.write_file(GLOBALS.SCRIPT_PRE_OUTPUT_FILE, output.stdout) then
            Logger.error("write " .. GLOBALS.SCRIPT_PRE_OUTPUT_FILE .. " fail")
          end
        elseif type == "post_request" then
          if not FS.write_file(GLOBALS.SCRIPT_POST_OUTPUT_FILE, output.stdout) then
            Logger.error("write " .. GLOBALS.SCRIPT_POST_OUTPUT_FILE .. " fail")
          end
        end
      end
    end
  end
end

return M
