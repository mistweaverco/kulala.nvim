local M = {}

M.data = {
  selected_env = nil, -- string - name of selected env
  http_client_env = nil, -- table of envs from http-client.env.json
  http_client_env_base = nil, -- table of base env values which should be applied to all requests
  env = {}, -- table of envs from document sources
}

return M
