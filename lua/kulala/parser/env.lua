local FS = require('kulala.utils.fs')
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
    env = vim.tbl_extend('force', env, vim.fn.json_decode(vim.fn.readfile(http_client_env_json)))
  elseif dotenv then
    local dotenv_env = vim.fn.readfile(dotenv)
    for _, line in ipairs(dotenv_env) do
      local key, value = line:match('([^=]+)=(.*)')
      env[key] = value
    end
  end
  return env
end

return M
