local Config = require("kulala.config")
local FS = require("kulala.utils.fs")
local DB = require("kulala.db")

local M = {}

M.get_env = function()
  local http_client_env_json = FS.find_file_in_parent_dirs("http-client.env.json")
  local dotenv = FS.find_file_in_parent_dirs(".env")
  local env = {}

  for key, value in pairs(vim.fn.environ()) do
    env[key] = value
  end

  if dotenv then
    local dotenv_env = vim.fn.readfile(dotenv)
    for _, line in ipairs(dotenv_env) do
      -- if the line is not empy and not a comment, then
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
    if f._base then
      DB.data.http_client_env_base = f._base
    end
    f._base = nil
    DB.data.http_client_env = f
    local selected_env = f[vim.g.kulala_selected_env or Config.get().default_env]
    if selected_env then
      env = vim.tbl_extend("force", env, selected_env)
    end
  end

  for key, value in pairs(DB.data.env) do
    env[key] = value
  end

  return env
end

return M
