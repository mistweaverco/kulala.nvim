local Config = require("kulala.config")
local DB = require("kulala.db")
local Env = require("kulala.parser.env")
local Logger = require("kulala.logger")
local table = require("kulala.utils.table")

local M = {}
-- LOG = vim.schedule_wrap(LOG)
--"Authorization Code", "Client Credentials", "Device Authorization", "Implicit", and "Password".

---@param url string
---@param body string
---@param request_type string - description of the request
---@return table|nil
local function make_request(url, body, request_type)
  local headers = "Content-Type: application/x-www-form-urlencoded"
  local cmd = { Config.get().curl_path, "-s", "-X", "POST", "-H", headers, "-d", body, url }

  local status, result = pcall(function()
    return vim.system(cmd, { text = true }):wait()
  end)

  local error

  if not status then
    error = "Request error:\n" .. result
  elseif result and result.code ~= 0 then
    error = "Request error:\n" .. result.stderr
  end

  result = result or { stdout = "" }
  status, result = pcall(vim.json.decode, result.stdout or "", { object = nil, array = nil })
  if not status then error = "Error parsing authentication response:\n" .. result end

  if result.error then error = result.error .. "\n" .. result.error_description end
  if error then return Logger.error("Failed to: " .. request_type .. ". " .. error, 2) end

  return result
end

local function get_auth_config(config_id)
  local cur_env = vim.g.kulala_selected_env or Config.get().default_env
  local env = DB.find_unique("http_client_env") and DB.find_unique("http_client_env")[cur_env] or {}
  return vim.tbl_get(env, "Security", "Auth", config_id) or {}
end

local function validate_auth_params(config_id, keys)
  local config = get_auth_config(config_id)
  local valid = true

  vim.iter(keys):each(function(key)
    if not config[key] then
      valid = false
      return Logger.error("Missing required field [" .. key .. "] in the Auth config: " .. config_id)
    end
  end)

  return valid
end

local function update_auth_config(config_id, update)
  local config = vim.tbl_extend("force", get_auth_config(config_id), update)
  Env.update_http_client_auth(config_id, config)
  Env.get_env()

  return config
end

local function parse_params(request)
  request = request:match("/%?(.+) HTTP")
  request = vim.split(request or "", "&") or {}

  return vim.iter(request):fold({}, function(acc, param)
    local key, value = unpack(vim.split(param, "="))
    acc[key] = vim.uri_decode(value or "")
    return acc
  end)
end

M.receive_code = function(config_id)
  local config = get_auth_config(config_id)
  local url = config["Redirect URL"]

  if not url:find("localhost") and not url:find("127.0.0.1") then
    return vim.uri_decode(vim.fn.input("Enter the auth code: "))
  end

  local port = url:match(":(%d+)")
  port = port or 80

  M.tcp_server("127.0.0.1", port, function(request)
    local params = parse_params(request) or {}

    if params.code then
      vim.schedule(function()
        update_auth_config(config_id, params)
      end)
      return "Code received.  You can close the browser now."
    end
  end)

  Logger.info("Waiting for authorization code")
  local wait = vim.wait(30000, function()
    config = get_auth_config(config_id)
    return config.code
  end)

  if not wait then return Logger.error("Timeout waiting for authorization code for: " .. config_id) end

  return config.code
end

M.acquire_code = function(config_id)
  local config = get_auth_config(config_id)
  table.remove_keys(config, { "code" })

  config = update_auth_config(config_id, config)

  if not validate_auth_params(config_id, { "Grant Type", "Client ID", "Redirect URL", "Auth URL" }) then return end

  local url = config["Auth URL"]
  local body = "scope="
    .. vim.uri_encode(config["Scope"])
    .. "&access_type=offline"
    .. "&include_granted_scopes=true"
    .. "&response_type=code"
    .. "&redirect_uri="
    .. config["Redirect URL"]
    .. "&client_id="
    .. config["Client ID"]

  -- state=state_parameter_passthrough_value& -- TODO: add optional parameters to request

  local uri = url .. "?" .. body

  Logger.info("Acquiring code for config: " .. config_id)
  vim.ui.open(uri)

  local code = M.receive_code(config_id)
  if not code then return Logger.error("Failed to acquire code for config: " .. config_id) end

  return code
end

M.acquire_token = function(config_id)
  local config = get_auth_config(config_id)
  local code = M.acquire_code(config_id)

  if
    not code
    or not validate_auth_params(config_id, { "Grant Type", "Client ID", "Client Secret", "Redirect URL", "Token URL" })
  then
    return
  end

  local url = config["Token URL"]
  local body = "client_id="
    .. config["Client ID"]
    .. "&client_secret="
    .. config["Client Secret"]
    .. "&code="
    .. code
    .. "&redirect_uri="
    .. config["Redirect URL"]
    .. "&grant_type=authorization_code"

  Logger.info("Acquiring new token for config: " .. config_id)

  local out = make_request(url, body, "acquire token")
  if not out then return end

  out.acquired_at = os.time()
  out.refresh_token_acquired_at = os.time()

  config = update_auth_config(config_id, out)

  return config.access_token
end

M.refresh_token = function(config_id)
  local config = get_auth_config(config_id)
  local refresh_token = not M.is_token_expired(config_id, "refresh_token") and config.refresh_token
  if not refresh_token then return M.acquire_token(config_id) end

  if not validate_auth_params(config_id, { "Grant Type", "Client ID", "Client Secret", "Token URL" }) then return end

  local url = config["Token URL"]
  local body = "client_id="
    .. config["Client ID"]
    .. "&client_secret="
    .. config["Client Secret"]
    .. "&refresh_token="
    .. refresh_token
    .. "&grant_type=refresh_token"

  Logger.info("Refreshing token for config: " .. config_id)

  local out = make_request(url, body, "refresh token")
  if not out then return end

  out.acquired_at = os.time()
  config = update_auth_config(config_id, out)

  return config.access_token
end

M.get_token = function(config_id)
  local config = get_auth_config(config_id)

  local token = not M.is_token_expired(config_id) and config.access_token
  return token or M.refresh_token(config_id)
end

M.get_idToken = function(config_id)
  local config = get_auth_config(config_id)

  local token = not M.is_token_expired(config_id) and config.id_token
  _ = not token and M.refresh_token(config_id)

  return config.id_token
end

M.revoke_token = function(config_id)
  M.test()
  local config = get_auth_config(config_id)

  local token = config.access_token
  if not token or not validate_auth_params(config_id, { "Revoke URL" }) then return end

  local url = config["Revoke URL"]
  local body = "token=" .. config.access_token

  Logger.info("Revoking token for config: " .. config_id)

  make_request(url, body, "revoke token")

  table.remove_keys(config, {
    "code",
    "access_token",
    "refresh_token",
    "acquired_at",
    "expires_in",
    "refresh_token_acquired_at",
    "refresh_token_expires_in",
  })
  update_auth_config(config_id, config)

  return true
end

M.is_token_expired = function(config_id, type)
  M.test()
  type = type and type .. "_" or ""
  local config = get_auth_config(config_id)

  local acquired_at = config[type .. "acquired_at"]
  local expires_in = config[type .. "expires_in"]

  if not acquired_at or not expires_in then return true end

  local diff = os.difftime(os.time(), acquired_at)
  _ = diff > expires_in
    and Logger.warn((type == "" and "Access" or "Refresh") .. " token expired for config: " .. config_id)

  return diff > expires_in, expires_in - diff
end

M.test = function()
  DB.current_buffer = vim.fn.bufnr("gapi.http")
  Env.get_env()
end

local function stop_server(server, client)
  client:shutdown()
  client:close()

  server:shutdown()
  server:close()
end

M.tcp_server = function(host, port, on_request)
  host = host or "127.0.0.1"
  port = port or 8080

  local server = vim.uv.new_tcp() or {}
  server:bind(host, port)

  server:listen(128, function(err)
    if err then return Logger.error("Failed to start TCP server: " .. err) end

    local client = vim.uv.new_tcp() or {}
    server:accept(client)

    client:read_start(function(err, chunk)
      if err then return Logger.error("Failed to read server response: " .. err) end

      if chunk then
        local response = on_request(chunk)
        if not response then return end

        client:write("HTTP/1.1 200 OKn\r\n\r\n" .. response .. "\n")
        pcall(stop_server, server, client)
      else
        pcall(stop_server, server, client)
      end
    end)
  end)

  vim.uv.run()
end

return M
