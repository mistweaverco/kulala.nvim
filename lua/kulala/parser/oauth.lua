local Config = require("kulala.config")
local DB = require("kulala.db")
local Env = require("kulala.parser.env")
local Jwt = require("kulala.parser.jwt")
local Logger = require("kulala.logger")
local table = require("kulala.utils.table")

local M = {}

local request_timeout = 30000 -- 30 seconds
local request_interval = 5000 -- 5 seconds

---@param url string
---@param body string
---@param request_desc string - description of the request
---@return table|nil, string|nil - response and error message
local function make_request(url, body, request_desc)
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
  if error then return Logger.error("Failed to: " .. request_desc .. ". " .. error, 2), error end

  return result
end

---@return table - get the auth config for the current environment, under Security.Auth
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

---Updates the auth config for the current environment and persists changes in http_client_env.json
---@param config_id string
---@param update table - new values to update the auth config
local function update_auth_config(config_id, update)
  local config = vim.tbl_extend("force", get_auth_config(config_id), update)

  Env.update_http_client_auth(config_id, config)
  Env.get_env()

  return config
end

---Grant Type "Device Authorization"
---Acquire a device code for the given config_id
M.get_device_code = function(config_id)
  local config = get_auth_config(config_id)
  if not validate_auth_params(config_id, { "Client ID", "Device Auth URL", "Scope" }) then return end

  local url = config["Device Auth URL"]
  local body = "client_id=" .. config["Client ID"] .. "&scope=" .. vim.uri_encode(config["Scope"])

  Logger.info("Acquiring device code for config: " .. config_id)

  local out = make_request(url, body, "acquire device code")
  if not out then return end

  out.acquired_at = os.time()
  config = update_auth_config(config_id, out)

  return config.device_code
end

---Grant Type "Device Authorization"
---Verify the device code for the given config_id
---Open browser with the verification URL and copy the user code to the clipboard
M.verify_device_code = function(config_id)
  local config = get_auth_config(config_id)
  if not validate_auth_params(config_id, { "verification_url", "user_code" }) then return end

  local browser, status = vim.ui.open(config.verification_url)
  if not browser then return Logger.error("Failed to open browser: " .. status) end

  vim.fn.setreg("+", config.user_code)
end

---Grant Type "Device Authorization"
---Acquire a device token for the given config_id
M.get_device_token = function(config_id)
  local config = get_auth_config(config_id)
  local device_code = M.get_device_code(config_id)

  local required_params = { "Grant Type", "Client ID", "Client Secret", "Token URL" }
  if not device_code or not validate_auth_params(config_id, required_params) then return end

  M.verify_device_code(config_id)

  local url = config["Token URL"]
  local body = "client_id="
    .. config["Client ID"]
    .. "&client_secret="
    .. config["Client Secret"]
    .. "&device_code="
    .. device_code
    .. "&grant_type=urn:ietf:params:oauth:grant-type:device_code"

  Logger.info("Acquiring device token for config: " .. config_id)

  local period = config.interval and tonumber(config.interval) * 2000 or request_interval
  Logger.info("Waiting for device token")

  local out, err
  vim.wait(request_timeout * 2, function()
    vim.uv.sleep(request_interval)

    out, err = make_request(url, body, "acquire device token")
    err = err or ""

    if not out and not err:match("authorization_pending") and not err:match("slow_down") then return true end
    out = out or {}

    return out.access_token or os.difftime(os.time(), config.acquired_at) > config.expires_in
  end, period)

  if not out.access_token then return Logger.error("Timeout acquiring device token for config: " .. config_id) end

  out.acquired_at = os.time()
  config = update_auth_config(config_id, out)

  return config.access_token
end

local function parse_params(request)
  request = request:match("/%?(.+) HTTP")
  request = vim.split(request or "", "&") or {}

  return vim.iter(request):fold({}, function(acc, param)
    local key, value = unpack(vim.split(param, "="))
    if key and value then acc[key] = vim.uri_decode(value or "") end
    return acc
  end)
end

---Grant Type "Authorization Code" or "Implicit"
---Intercept the auth code or access token from browser redirect if redirect is to localhost
---Otherwise, ask the user to input the auth code
M.receive_code = function(config_id)
  local config = get_auth_config(config_id)
  local url = config["Redirect URL"]

  if not url:find("localhost") and not url:find("127.0.0.1") then
    return vim.uri_decode(vim.fn.input("Enter the Auth code: "))
  end

  local port = url:match(":(%d+)") or 80

  M.tcp_server("127.0.0.1", port, function(request)
    local params = parse_params(request) or {}

    if params.code or params.access_token then
      vim.schedule(function()
        if params.access_token then params.acquired_at = os.time() end
        update_auth_config(config_id, params)
      end)
      return "Code/Token received.  You can close the browser now."
    end
  end)

  Logger.info("Waiting for authorization code/token")
  local wait = vim.wait(request_timeout, function()
    config = get_auth_config(config_id)
    return config.code or config.access_token
  end)

  if not wait then return Logger.error("Timeout waiting for authorization code/token for: " .. config_id) end

  return config.code or config.access_token
end

M.create_JWT = function(config_id)
  local config = get_auth_config(config_id)
  if not validate_auth_params(config_id, { "Grant Type", "iss", "aud", "Scope", "private_key" }) then return end

  local expires_in = 50

  local header = { alg = "RS256" }
  local payload = {
    iss = config.iss,
    aud = config.aud,
    scope = config.Scope,
    exp = os.time() + expires_in,
    iat = os.time(),
  }

  return Jwt.encode(header, payload, config.private_key)
end

---Grant Type "Client Credentials"
---Acquire a token using the client credentials for the given config_id
M.acquire_token_jwt = function(config_id)
  local config = get_auth_config(config_id)
  local assertion = config.assertion or M.create_JWT(config_id)

  if not assertion or not validate_auth_params(config_id, { "Grant Type", "Token URL" }) then return end
  local url = config["Token URL"]
  local body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" .. assertion

  Logger.info("Acquiring token for config: " .. config_id)

  local out = make_request(url, body, "acquire token")
  if not out then return end

  out.acquired_at = os.time()
  config = update_auth_config(config_id, out)

  return config.access_token
end

---Grant Type "Authorization Code" or "Implicit"
---Acquire an auth code for the given config_id
M.acquire_code = function(config_id)
  local config = get_auth_config(config_id)

  local required_params = { "Grant Type", "Client ID", "Redirect URL", "Auth URL", "Scope" }
  if not validate_auth_params(config_id, required_params) then return end

  local url = config["Auth URL"]
  local body = "scope="
    .. vim.uri_encode(config["Scope"])
    .. "&include_granted_scopes=true"
    .. "&redirect_uri="
    .. config["Redirect URL"]
    .. "&client_id="
    .. config["Client ID"]

  body = config["Grant Type"] == "Authorization Code" and body .. "&access_type=offline&response_type=code" or body
  body = config["Grant Type"] == "Implicit" and body .. "&response_type=token" or body

  -- state=state_parameter_passthrough_value& -- TODO: add optional parameters to request

  local uri = url .. "?" .. body

  Logger.info("Acquiring code for config: " .. config_id)

  local browser, status = vim.ui.open(uri)
  if not browser then return Logger.error("Failed to open browser: " .. status) end

  local code = M.receive_code(config_id)
  if not code then return Logger.error("Failed to acquire code for config: " .. config_id) end

  return code
end

---Grant Type "Authorization Code" or "Implicit" or "Device Authorization" or "Client Credentials"
---Acquire a new token for the given config_id
M.acquire_token = function(config_id)
  local config = get_auth_config(config_id)

  table.remove_keys(config, { "code", "device_code", "user_code", "access_token", "id_token", "refresh_token" })
  config = update_auth_config(config_id, config)

  if config["Grant Type"] == "Device Authorization" then return M.get_device_token(config_id) end
  if config["Grant Type"] == "Client Credentials" then return M.acquire_token_jwt(config_id) end

  local code = M.acquire_code(config_id)
  if config["Grant Type"] == "Implicit" then return code end

  local required_params = { "Grant Type", "Client ID", "Client Secret", "Redirect URL", "Token URL" }
  if not code or not validate_auth_params(config_id, required_params) then return end

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
  if out.refresh_token then out.refresh_token_acquired_at = os.time() end

  config = update_auth_config(config_id, out)

  return config.access_token
end

---Grant Type "Authorization Code" or "Device Authorization"
---Refresh the token for the given config_id
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

---Grant Type - all
---Entry point to get the token for the given config_id
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

---Revoke the token for the given config_id
M.revoke_token = function(config_id)
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
    "id_token",
    "refresh_token",
    "acquired_at",
    "expires_in",
    "refresh_token_acquired_at",
    "refresh_token_expires_in",
  })
  update_auth_config(config_id, config)

  return true
end

---Check if the token for the given config_id is expired
---@param config_id string
---@param type string|nil - default: "access" | "refresh"
M.is_token_expired = function(config_id, type)
  type = type and type .. "_" or ""
  local config = get_auth_config(config_id)

  local acquired_at = tonumber(config[type .. "acquired_at"])
  local expires_in = tonumber(config[type .. "expires_in"])

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

local function stop_server(server)
  server:shutdown()
  server:close()
end

local function stop_client(client)
  client:shutdown()
  client:close()
end

local function redirect_script()
  return [[
    <!DOCTYPE html>
    <html>
    <body>
      <p>Processing authentication...</p>
      <script>
        const fragment = window.location.hash.substring(1);
        
        if (fragment && fragment.includes('access_token=')) {
          window.location.href = '\/?' + fragment;
        } else {
          document.body.innerHTML = '<p>No access token found in URL fragment.</p>';
        }
      </script>
    </body>
    </html>
  ]]
end

M.tcp_server = function(host, port, on_request)
  host = host or "127.0.0.1"
  port = port or 80

  local server = vim.uv.new_tcp() or {}
  server:bind(host, port)

  server:listen(128, function(err)
    if err then return Logger.error("Failed to start TCP server: " .. err) end
    Logger.info("Server listening for code/token on " .. host .. ":" .. port)

    local client = vim.uv.new_tcp() or {}
    server:accept(client)

    client:read_start(function(err, chunk)
      if err then return Logger.error("Failed to read server response: " .. err) end
      ---@diagnostic disable-next-line: redundant-return-value
      if not chunk then return pcall(stop_client, client) end

      local response, result

      if chunk:match("GET / HTTP") then
        response = redirect_script()
      elseif chunk:match("GET /%?") then
        result = on_request(chunk)
        response = result or "OK"
      end

      client:write("HTTP/1.1 200 OKn\r\n\r\n" .. response .. "\n")
      pcall(stop_client, client)

      if result then pcall(stop_server, server) end
    end)
  end)

  vim.uv.run()
end

return M
