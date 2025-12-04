local Config = require("kulala.config")
local DB = require("kulala.db")
local FS = require("kulala.utils.fs")
local Logger = require("kulala.logger")
local Table = require("kulala.utils.table")

local M = {}

local function get_vscode_env()
  if Config.get().vscode_rest_client_environmentvars then
    local vscode_settings_file = FS.find_file_in_parent_dirs(".vscode/settings.json")
    local code_workspace_file = FS.find_file_in_parent_dirs(function(name, _)
      return name:match(".*%.code%-workspace$")
    end)

    if vscode_settings_file then
      local settings = FS.read_json(vscode_settings_file) or {}
      if not (settings and settings["rest-client.environmentVariables"]) then return end

      local f = settings["rest-client.environmentVariables"]
      if f["$shared"] then
        DB.update().http_client_env_shared =
          vim.tbl_deep_extend("force", DB.find_unique("http_client_env_shared"), f["$shared"])
      end

      f["$shared"] = nil
      DB.update().http_client_env = vim.tbl_deep_extend("force", DB.find_unique("http_client_env"), f)
    end

    if code_workspace_file then
      local code_workspace = FS.read_json(code_workspace_file) or {}

      local settings = code_workspace.settings
      if not (settings and settings["rest-client.environmentVariables"]) then return end

      local f = settings["rest-client.environmentVariables"]
      if f["$shared"] then
        DB.update().http_client_env_shared =
          vim.tbl_deep_extend("force", DB.find_unique("http_client_env_shared"), f["$shared"])
      end

      f["$shared"] = nil
      DB.update().http_client_env = vim.tbl_deep_extend("force", DB.find_unique("http_client_env"), f)
    end
  end
end

local function get_dot_env(env)
  local dotenv = FS.find_file_in_parent_dirs(".env")

  if dotenv then
    local dotenv_env = vim.fn.readfile(dotenv)

    for _, line in ipairs(dotenv_env) do
      -- if the line is not empty and not a comment, then
      if not line:match("^%s*$") and not line:match("^%s*#") then
        local key, value = line:match("^%s*([^=]+)%s*=%s*(.*)%s*$")

        if key and value then env[key] = value end
      end
    end
  end

  return env
end

local function get_http_client_env(name)
  local envs = FS.find_files_in_parent_dirs(name) or {}

  vim.iter(envs):rev():each(function(file)
    local f = FS.read_json(file) or {}

    if f["$shared"] then
      DB.update().http_client_env_shared =
        vim.tbl_deep_extend("force", DB.find_unique("http_client_env_shared"), f["$shared"])
    end

    f["$shared"], f["$schema"] = nil, nil
    DB.update().http_client_env = vim.tbl_deep_extend("force", DB.find_unique("http_client_env"), f)
  end)
end

local function create_private_env()
  local env_path = FS.find_file_in_parent_dirs("http-client.env.json")
  env_path = env_path and vim.fn.fnamemodify(env_path, ":h") or FS.get_current_buffer_dir()

  local private_env_path = env_path .. "/http-client.private.env.json"
  local cur_env = M.get_current_env()

  local env = { [cur_env] = { Security = { Auth = {} } } }
  FS.write_json(private_env_path, env)
  Logger.info("Created private env file: " .. private_env_path)

  return private_env_path
end

M.update_http_client_auth = function(config_id, data)
  local env_path = FS.find_file_in_parent_dirs("http-client.private.env.json")
  env_path = env_path or create_private_env()

  local env = FS.read_json(env_path)
  if not env then return end

  local cur_env = M.get_current_env()
  Table.set_at(env, { cur_env, "Security", "Auth", config_id, "auth_data" }, data)

  FS.write_json(env_path, env, true)
end

local function get_scripts_variables(env)
  local global_scripts_variables = FS.get_global_scripts_variables()
  local request_scripts_variables = FS.get_request_scripts_variables()

  if global_scripts_variables then env = vim.tbl_extend("force", env, global_scripts_variables) end
  if request_scripts_variables then env = vim.tbl_extend("force", env, request_scripts_variables) end

  return env
end

M.get_current_env = function()
  return vim.g.kulala_selected_env or Config.get().default_env
end

M.get_env = function()
  local env = {}

  for key, value in pairs(vim.fn.environ()) do
    env[key] = value
  end

  DB.update().http_client_env_shared = {}
  DB.update().http_client_env = {}

  get_vscode_env()
  env = get_dot_env(env)

  get_http_client_env("http-client.env.json")
  get_http_client_env("http-client.private.env.json")

  local cur_env = M.get_current_env()
  local selected_env = DB.find_unique("http_client_env") and DB.find_unique("http_client_env")[cur_env] or {}
  local shared = DB.find_unique("http_client_env_shared") or {}

  selected_env = vim.tbl_deep_extend("force", shared, selected_env)
  env = vim.tbl_deep_extend("force", env, selected_env)

  local db_env = DB.find_unique("env") or {}
  for key, value in pairs(db_env) do
    env[key] = value
  end

  env = get_scripts_variables(env)

  return env
end

return M
