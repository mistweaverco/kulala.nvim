local Fs = require("kulala.utils.fs")
local M = {}

local NODE_EXISTS = vim.fn.executable("node") == 1
local SCRIPTS_DIR = Fs.get_scripts_dir()
local REQUEST_SCRIPTS_DIR = Fs.get_request_scripts_dir()
local BASE_FILE_PRE = Fs.join_paths(SCRIPTS_DIR, "pre_request_base.js")
local BASE_FILE_POST = Fs.join_paths(SCRIPTS_DIR, "post_request_base.js")

local generate_one = function(script_type, is_external_file, script_data)
  local lines
  local base_file_path = script_type == "pre_request" and BASE_FILE_PRE or BASE_FILE_POST
  local base_file = Fs.read_file(base_file_path)
  if base_file == nil then
    return nil, nil
  end
  local script_cwd
  if is_external_file then
    -- if script_data starts with ./ or ../, it is a relative path
    if string.match(script_data, "^%./") or string.match(script_data, "^%../") then
      script_data = Fs.get_current_buffer_dir() .. Fs.ps .. script_data:gsub("^%./", "")
    end
    script_cwd = Fs.get_dir_by_filepath(script_data)
    lines = Fs.read_file_lines(script_data)
  else
    script_cwd = Fs.get_current_buffer_dir()
    lines = script_data
  end
  for _, line in ipairs(lines) do
    base_file = base_file .. "\n" .. line
  end
  if #lines == 0 then
    return nil, nil
  end
  local uuid = Fs.get_uuid()
  local script_path = REQUEST_SCRIPTS_DIR .. Fs.ps .. uuid .. ".js"
  Fs.write_file(script_path, base_file)
  return script_path, script_cwd
end

---@class Scripts
---@field path string -- path to script
---@field cwd string -- current working directory

---@class ScriptData table -- data for script
---@field inline string<table> -- inline scripts
---@field files string<table> -- paths to script files

---@param script_type string -- "pre_request" or "post_request"
---@param scripts_data ScriptData
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

---@param type string -- "pre_request" or "post_request"
---@param data ScriptData
M.run = function(type, data)
  if not NODE_EXISTS then
    return
  end
  local scripts = generate_all(type, data)
  if scripts == nil then
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
          NODE_PATH = script.cwd .. Fs.ps .. "node_modules",
        },
      })
      :wait()
    if output ~= nil then
      if output.stderr ~= nil then
        vim.print(output.stderr)
      end
      if output.stdout ~= nil then
        vim.print(output.stdout)
      end
    end
  end
end

return M
