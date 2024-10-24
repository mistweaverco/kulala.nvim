local Config = require("kulala.config")
local FS = require("kulala.utils.fs")
local DB = require("kulala.db")

local M = {}

M.get_env = function()
  local http_client_env_json = FS.find_file_in_parent_dirs("http-client.env.json")
  local http_client_private_env_json = FS.find_file_in_parent_dirs("http-client.private.env.json")
  local dotenv = FS.find_file_in_parent_dirs(".env")
  local env = {}

  for key, value in pairs(vim.fn.environ()) do
    env[key] = value
  end

  DB.update().http_client_env_shared = {}
  DB.update().http_client_env = {}

  if Config.get().vscode_rest_client_environmentvars then
    local vscode_dir = FS.find_file_in_parent_dirs(".vscode")
    local code_workspace_file = FS.find_file_in_parent_dirs(function(name, path)
      return name:match(".*%.code%-workspace$")
    end)

    if vscode_dir then
      local success, settings_json_content = pcall(vim.fn.readfile, vscode_dir .. "/settings.json")
      if success then
        local settings = vim.fn.json_decode(settings_json_content)
        if settings and settings["rest-client.environmentVariables"] then
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

    if code_workspace_file then
      local code_workspace = vim.fn.json_decode(vim.fn.readfile(code_workspace_file))
      local settings = code_workspace.settings
      if settings and settings["rest-client.environmentVariables"] then
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

  if dotenv then
    local dotenv_env = vim.fn.readfile(dotenv)
    for _, line in ipairs(dotenv_env) do
      -- if the line is not empty and not a comment, then
      if not line:match("^%s*$") and not line:match("^%s*#") then
        local key, value = line:match("^%s*([^=]+)%s*=%s*(.*)%s*$")
        if key and value then
          env[key] = value
        end
      end
    end
  end

  if http_client_env_json then
    local f = vim.fn.json_decode(vim.fn.readfile(http_client_env_json))
    if f["$shared"] then
      DB.update().http_client_env_shared =
        vim.tbl_deep_extend("force", DB.find_unique("http_client_env_shared"), f["$shared"])
    end
    f["$shared"] = nil
    DB.update().http_client_env = vim.tbl_deep_extend("force", DB.find_unique("http_client_env"), f)
  end

  if http_client_private_env_json then
    local f = vim.fn.json_decode(vim.fn.readfile(http_client_private_env_json))
    if f["$shared"] then
      DB.update().http_client_env_shared =
        vim.tbl_deep_extend("force", DB.find_unique("http_client_env_shared"), f["$shared"])
    end
    f["$shared"] = nil
    DB.update().http_client_env = vim.tbl_deep_extend("force", DB.find_unique("http_client_env"), f)
  end

  local http_client_env_shared = DB.find_unique("http_client_env_shared") or {}
  for key, value in pairs(http_client_env_shared) do
    if key ~= "$default_headers" then
      env[key] = value
    end
  end

  local selected_env = DB.find_unique("http_client_env")[vim.g.kulala_selected_env or Config.get().default_env]
  if selected_env then
    env = vim.tbl_extend("force", env, selected_env)
  end

  local db_env = DB.find_unique("env") or {}
  for key, value in pairs(db_env) do
    env[key] = value
  end

  local global_scripts_variables = FS.get_global_scripts_variables()
  if global_scripts_variables then
    env = vim.tbl_extend("force", env, global_scripts_variables)
  end

  local request_scripts_variables = FS.get_request_scripts_variables()
  if request_scripts_variables then
    env = vim.tbl_extend("force", env, request_scripts_variables)
  end

  return env
end

return M
