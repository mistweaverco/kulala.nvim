local Config = require("kulala.config")
local Crypto = require("kulala.cmd.crypto")
local DB = require("kulala.db")
local Env = require("kulala.parser.env")
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

  result = result or { stdout = "{}" }
  status, result = pcall(vim.json.decode, result.stdout or "", { object = nil, array = nil })
  if not status then error = "Error parsing authentication response:\n" .. result end

  if result.error then error = result.error .. "\n" .. result.error_description end
  if error then return Logger.error("Failed to: " .. request_desc .. ". " .. error, 2), error end

  return result
end

---@return table - get the auth config for the current environment, under Security.Auth
local function get_auth_config(config_id)
  local cur_env = vim.g.kulala_selected_env or Config.get().default_env
  local env = Env.get_env() and DB.find_unique("http_client_env") or {}

  local auth_config = vim.tbl_get(env, cur_env, "Security", "Auth", config_id) or {}
  auth_config.auth_data = auth_config.auth_data or {}

  return auth_config
end

local function validate_auth_params(config_id, keys, nested_key)
  local config = get_auth_config(config_id)
  config = nested_key and config[nested_key] or config

  local valid = true

  vim.iter(keys):each(function(key)
    if not (config[key] and #tostring(config[key]) > 0) then
      valid = false
      return Logger.error("Missing required field [" .. key .. "] in the Auth config: " .. config_id)
    end
  end)

  return valid
end

---Updates the auth data for the current environment and config and persists changes in http-client.private.env.json
---@param config_id string
---@param data table - new values to update the auth config
---@param replace boolean|nil - replace the existing auth data
local function update_auth_data(config_id, data, replace)
  local auth_data = replace and data or vim.tbl_extend("force", get_auth_config(config_id).auth_data, data)

  Env.update_http_client_auth(config_id, auth_data)
  return get_auth_config(config_id)
end

local function to_query(key, value)
  if type(value) == "table" and not vim.islist(value) then return "nested tables not supported" end
  value = vim.islist(value) and value or { value }

  return vim.iter(value):fold("", function(ret, v)
    ret = ret .. "&" .. key .. "=" .. v
    return ret
  end)
end

local function add_pkce(config_id, body, request_type)
  local config = get_auth_config(config_id)
  local pkce = config.PKCE

  if not pkce then return body end
  pkce = pkce == true and {} or pkce

  local challenge_method = pkce["Code Challenge Method"] or "S256"
  local verifier = config.auth_data.pkce_verifier or pkce["Code Verifier"] or Crypto.pkce_verifier()

  config.auth_data.pkce_verifier = request_type == "auth" and verifier or nil

  local challenge = Crypto.pkce_challenge(verifier, challenge_method)

  if not verifier or not challenge then
    return body, Logger.error("Failed to create PKCE pair for config " .. config_id)
  end

  if request_type == "auth" then
    body = body .. "&code_challenge=" .. challenge .. "&code_challenge_method=" .. challenge_method
  elseif request_type == "token" then
    body = body .. "&code_verifier=" .. verifier
  end

  return body
end

---Add custom request parameters to the reuqest body
---@param config_id string
---@param body string
---@param use string - "Everywhere" | "In Auth Request" | "In Token Request"
local function add_custom_params(config_id, body, use)
  local config = get_auth_config(config_id)
  local custom_params = config["Custom Request Parameters"]

  if not custom_params then return body end

  vim.iter(custom_params):each(function(key, value)
    local _use = type(value) == "table" and value.Use or "Everywhere"
    local _value = type(value) == "table" and value.Value or value

    if _use == use or _use == "Everywhere" then body = body .. to_query(key, _value) end
  end)

  return body
end

---Grant Type "Device Authorization"
---Acquire a device code for the given config_id
M.get_device_code = function(config_id)
  local config = get_auth_config(config_id)
  if not validate_auth_params(config_id, { "Client ID", "Device Auth URL" }) then return end

  local url = config["Device Auth URL"]
  local body = "client_id=" .. config["Client ID"]

  body = config["Scope"] and body .. "&scope=" .. config["Scope"] or body
  body = add_custom_params(config_id, body, "In Auth Request")

  Logger.info("Acquiring device code for config: " .. config_id)

  local out = make_request(url, body, "acquire device code")
  if not out then return end

  out.acquired_at = os.time()
  config = update_auth_data(config_id, out)

  return config.auth_data.device_code
end

---Grant Type "Device Authorization"
---Verify the device code for the given config_id
---Open browser with the verification URL and copy the user code to the clipboard
M.verify_device_code = function(config_id)
  local config = get_auth_config(config_id)
  if not validate_auth_params(config_id, { "verification_url", "user_code" }, "auth_data") then return end

  local browser, status = vim.ui.open(config.auth_data.verification_url)
  if not browser then return Logger.error("Failed to open browser: " .. status) end

  Logger.info("Verification code: " .. config.auth_data.user_code)
  vim.fn.setreg("+", config.auth_data.user_code)
end

---Grant Type "Device Authorization"
---Acquire a device token for the given config_id
M.acquire_device_token = function(config_id)
  local device_code = M.get_device_code(config_id)
  local config = get_auth_config(config_id)

  local required_params = { "Grant Type", "Client ID", "Token URL" }
  if not device_code or not validate_auth_params(config_id, required_params) then return end

  M.verify_device_code(config_id)

  local url = config["Token URL"]
  local body = "client_id="
    .. config["Client ID"]
    .. "&device_code="
    .. device_code
    .. "&grant_type=urn:ietf:params:oauth:grant-type:device_code"

  body = config["Client Secret"] and body .. "&client_secret=" .. config["Client Secret"] or body
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Acquiring device token for config: " .. config_id)

  local period = config.auth_data.interval and tonumber(config.auth_data.interval) * 2000 or request_interval
  Logger.info("Waiting for device token.  Press <C-c> to cancel.")

  local out, err
  vim.wait(request_timeout * 2, function()
    vim.uv.sleep(request_interval)

    out, err = make_request(url, body, "acquire device token")
    err = err or ""

    if not out and not err:match("authorization_pending") and not err:match("slow_down") then return true end
    out = out or {}

    return out.access_token or os.difftime(os.time(), config.auth_data.acquired_at) > config.auth_data.expires_in
  end, period)

  if not out.access_token then return Logger.error("Timeout acquiring device token for config: " .. config_id) end

  out.acquired_at = os.time()
  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

local function parse_params(request)
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

  local server = M.tcp_server("127.0.0.1", port, function(request)
    local params = parse_params(request) or {}

    if params.code or params.access_token then
      vim.schedule(function()
        if params.access_token then params.acquired_at = os.time() end
        update_auth_data(config_id, params)
      end)
      return "Code/Token received.  You can close the browser now."
    end
  end)

  if not server then return end

  Logger.info("Waiting for authorization code/token.  Press <C-c> to cancel.")
  local wait = vim.wait(request_timeout, function()
    config = get_auth_config(config_id)
    return config.auth_data.code or config.auth_data.access_token
  end, request_interval)

  if not wait then
    server.stop()
    return Logger.error("Timeout waiting for authorization code/token for: " .. config_id)
  end

  return config.auth_data.code or config.auth_data.access_token
end

M.create_JWT = function(config_id)
  local config = get_auth_config(config_id)
  if not validate_auth_params(config_id, { "Grant Type", "JWT" }) then return end

  local jwt = vim.deepcopy(config.JWT)

  local header = vim.tbl_extend("keep", jwt.header or {}, { alg = "RS256", typ = "JWT" })
  local payload = jwt.payload or {}

  if (header.alg == "RS256" and not config.private_key) or (header.alg == "HS256" and not config["Client Secret"]) then
    return Logger.error(header.alg .. " key not found for config " .. config_id)
  end

  payload.exp = os.time() + (jwt.payload.exp or 50)
  payload.iat = os.time()

  return Crypto.jwt_encode(header, payload, config.private_key or config["Client Secret"])
end

---Grant Type "Client Credentials"
---Acquire a token using the client credentials for the given config_id
M.acquire_jwt_token = function(config_id)
  local config = get_auth_config(config_id)
  local assertion = config.Assertion or M.create_JWT(config_id)

  if not assertion or not validate_auth_params(config_id, { "Grant Type", "Token URL" }) then return end

  local url = config["Token URL"]
  local body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" .. assertion
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Acquiring token for config: " .. config_id)

  local out = make_request(url, body, "acquire token")
  if not out then return end

  out.acquired_at = os.time()
  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

---Grant Type "Authorization Code" or "Implicit"
---Acquire an auth code for the given config_id
M.acquire_auth = function(config_id)
  local config = get_auth_config(config_id)

  local required_params = { "Grant Type", "Client ID", "Redirect URL", "Auth URL" }
  if not validate_auth_params(config_id, required_params) then return end

  local url = config["Auth URL"]
  local body = "redirect_uri=" .. config["Redirect URL"] .. "&client_id=" .. config["Client ID"]

  local response_type = config["Grant Type"] == "Authorization Code" and "code" or "token"
  response_type = config["Response Type"] or response_type

  body = body .. "&response_type=" .. response_type
  body = config["Scope"] and body .. "&scope=" .. config["Scope"] or body

  body = add_pkce(config_id, body, "auth")
  body = add_custom_params(config_id, body, "In Auth Request")

  local uri = url .. "?" .. body

  Logger.info("Acquiring code for config: " .. config_id)

  local browser, status = vim.ui.open(uri)
  if not browser then return Logger.error("Failed to open browser: " .. status) end

  local code = M.receive_code(config_id)
  if not code then return Logger.error("Failed to acquire code for config: " .. config_id) end

  return code
end

M.acquire_password_token = function(config_id)
  local config = get_auth_config(config_id)
  local required_params = { "Client ID", "Client Secret", "Token URL", "Username", "Password" }
  if not validate_auth_params(config_id, required_params) then return end

  local url = config["Token URL"]
  local body = "client_id="
    .. config["Client ID"]
    .. "&username="
    .. config.Username
    .. "&password="
    .. config.Password
    .. "&grant_type=password"

  body = config["Client Secret"] and body .. "&client_secret=" .. config["Client Secret"] or body
  body = config["Scope"] and body .. "&scope=" .. config["Scope"] or body

  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Acquiring token for config: " .. config_id)

  local out = make_request(url, body, "acquire token")
  if not out then return end

  out.acquired_at = os.time()
  if out.refresh_token then out.refresh_token_acquired_at = os.time() end

  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

---Grant Type "Authorization Code" or "Implicit" or "Device Authorization" or "Client Credentials"
---Acquire a new token for the given config_id
M.acquire_token = function(config_id)
  local config = get_auth_config(config_id)

  table.remove_keys(
    config.auth_data,
    { "code", "device_code", "user_code", "access_token", "id_token", "refresh_token" }
  )
  config = update_auth_data(config_id, config.auth_data, true)

  if config["Grant Type"] == "Device Authorization" then return M.acquire_device_token(config_id) end
  if config["Grant Type"] == "Client Credentials" then return M.acquire_jwt_token(config_id) end
  if config["Grant Type"] == "Password" then return M.acquire_password_token(config_id) end

  local code = M.acquire_auth(config_id)
  if config["Grant Type"] == "Implicit" then return code end

  local required_params = { "Client ID", "Redirect URL", "Token URL" }
  if not code or not validate_auth_params(config_id, required_params) then return end

  local url = config["Token URL"]
  local body = "client_id="
    .. config["Client ID"]
    .. "&code="
    .. code
    .. "&redirect_uri="
    .. config["Redirect URL"]
    .. "&grant_type=authorization_code"

  body = config["Client Secret"] and body .. "&client_secret=" .. config["Client Secret"] or body

  body = add_pkce(config_id, body, "token")
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Acquiring new token for config: " .. config_id)

  local out = make_request(url, body, "acquire token")
  if not out then return end

  out.acquired_at = os.time()
  if out.refresh_token then out.refresh_token_acquired_at = os.time() end

  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

---Grant Type "Authorization Code" or "Device Authorization"
---Refresh the token for the given config_id
M.refresh_token = function(config_id)
  if not validate_auth_params(config_id, { "Grant Type" }) then return end

  local config = get_auth_config(config_id)
  if config["Acquire Automatically"] == false then return end

  local refresh_token = not M.is_token_expired(config_id, "refresh_token") and config.auth_data.refresh_token
  if not refresh_token then return M.acquire_token(config_id) end

  if not validate_auth_params(config_id, { "Client ID", "Token URL" }) then return end

  local url = config["Token URL"]
  local body = "client_id=" .. config["Client ID"] .. "&refresh_token=" .. refresh_token .. "&grant_type=refresh_token"

  body = config["Client Secret"] and body .. "&client_secret=" .. config["Client Secret"] or body
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Refreshing token for config: " .. config_id)

  local out = make_request(url, body, "refresh token")
  if not out then return end

  out.acquired_at = os.time()
  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

---Grant Type - all
---Entry point to get the token for the given config_id
M.get_token = function(config_id)
  local config = get_auth_config(config_id)
  if config["Use ID Token"] then return M.get_idToken(config_id) end

  local token = not M.is_token_expired(config_id) and config.auth_data.access_token
  return token or M.refresh_token(config_id)
end

M.get_idToken = function(config_id)
  local config = get_auth_config(config_id)

  local token = not M.is_token_expired(config_id) and config.auth_data.id_token
  _ = not token and M.refresh_token(config_id)

  return config.auth_data.id_token
end

---Revoke the token for the given config_id
M.revoke_token = function(config_id)
  local config = get_auth_config(config_id)

  local token = config.auth_data.access_token
  if not token then return Logger.info("No token to revoke for config: " .. config_id) end

  local body = "token=" .. config.auth_data.access_token

  Logger.info("Revoking token for config: " .. config_id)
  if validate_auth_params(config_id, { "Revoke URL" }) then make_request(config["Revoke URL"], body, "revoke token") end

  table.remove_keys(config.auth_data, {
    "code",
    "access_token",
    "id_token",
    "refresh_token",
    "acquired_at",
    "expires_in",
    "refresh_token_acquired_at",
    "refresh_token_expires_in",
  })
  update_auth_data(config_id, config.auth_data, true)

  return "Token revoked for config: " .. config_id
end

---Check if the token for the given config_id is expired
---@param config_id string
---@param type string|nil - default: "access" | "refresh"
M.is_token_expired = function(config_id, type)
  type = type and type .. "_" or ""
  local config = get_auth_config(config_id).auth_data

  local acquired_at = tonumber(config[type .. "acquired_at"])
  local expires_in = tonumber(config[type .. "expires_in"])

  if not acquired_at or not expires_in then return true end

  local diff = os.difftime(os.time(), acquired_at)
  _ = diff > expires_in
    and Logger.warn((type == "" and "Access" or "Refresh") .. " token expired for config: " .. config_id)

  return diff > expires_in, expires_in - diff
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
  port = tonumber(port) or 80

  local server = vim.uv.new_tcp() or {}
  local status, err = pcall(server.bind, server, host, port)
  if not status then return Logger.error("Failed to start TCP server: " .. err) end

  Logger.info("Server listening for code/token on " .. host .. ":" .. port)

  local function stop_tcp(tcp)
    pcall(function()
      tcp:shutdown()
      tcp:close()
    end)
  end

  server:listen(128, function(err)
    if err then return Logger.error("Failed to process request: " .. err) end

    local client = vim.uv.new_tcp() or {}
    server:accept(client)

    client:read_start(function(err, chunk)
      if err then return Logger.error("Failed to read server response: " .. err) end
      ---@diagnostic disable-next-line: redundant-return-value
      if not chunk then return stop_tcp(client) end

      local response, result

      if chunk:match("GET / HTTP") then
        response = redirect_script()
      elseif chunk:match("GET /%?") then
        result = on_request(chunk:match("GET /%?(.+) HTTP"))
        response = result or "OK"
      end

      client:write("HTTP/1.1 200 OKn\r\n\r\n" .. response .. "\n")
      stop_tcp(client)

      if result then stop_tcp(server) end
    end)
  end)

  vim.uv.run()

  return {
    stop = function()
      stop_tcp(server)
    end,
  }
end

return M
