local FS = require('kulala.utils.fs')
local GLOBAL_STORE = require('kulala.global_store')
local DYNAMIC_VARS = require('kulala.parser.dynamic_vars')

local M = {}

local http_client_env_json = FS.find_file_in_parent_dirs('http-client.env.json')
local dotenv = FS.find_file_in_parent_dirs('.env')

M.get_env = function()
  local env = {}
  for key, value in pairs(vim.fn.environ()) do
    env[key] = value
  end
  if http_client_env_json then
    local f = vim.fn.json_decode(vim.fn.readfile(http_client_env_json))
    GLOBAL_STORE.set('http_client_env_json', f)
    if not f then
      vim.notify('http-client.env.json is not a valid json file', vim.log.levels.ERROR)
      return env
    end
    local selected_env_name = GLOBAL_STORE.get('selected_env')
    local selected_env = f[selected_env_name]
    if selected_env then
      env = vim.tbl_extend('force', env, selected_env)
    else
      vim.notify('Selected environment ('.. selected_env_name ..') not found in http-client.env.json', vim.log.levels.ERROR)
    end
  elseif dotenv then
    local dotenv_env = vim.fn.readfile(dotenv)
    for _, line in ipairs(dotenv_env) do
      local key, value = line:match('([^=]+)=(.*)')
      env[key] = value
    end
  end
  return env
end

M.load_envs = M.get_env

return M
