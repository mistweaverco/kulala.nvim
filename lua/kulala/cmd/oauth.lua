local Async = require("kulala.utils.async")
local Config = require("kulala.config")
local Crypto = require("kulala.cmd.crypto")
local DB = require("kulala.db")
local Env = require("kulala.parser.env")
local Float = require("kulala.ui.float")
local Fs = require("kulala.utils.fs")
local Inlay = require("kulala.inlay")
local Json = require("kulala.utils.json")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")
local Table = require("kulala.utils.table")
local Tcp = require("kulala.cmd.tcp")

local M = {}

local request_timeout = 30000 -- 30 seconds
local request_interval = 5000 -- 5 seconds
local tcp_server
local co, exit

local function get_curl_flags()
  if not DB.current_request then return {} end

  local RequestParser = require("kulala.parser.request")
  local request = vim.deepcopy(DB.current_request)

  return Async.co_wrap(co, function()
    RequestParser.parse_metadata(request)
    return RequestParser.process_custom_curl_flags(request)
  end)
end

---@param url string
---@param body string
---@param request_desc string - description of the request
---@param params table|nil - additional parameters for the request
---@return table|nil, string|nil - response and error message
local function make_request(url, body, request_desc, params)
  local cmd = { Config.get().curl_path, "-s", "-X", "POST", "-H", "Content-Type: application/x-www-form-urlencoded" }

  local headers = params and params.headers or {}
  local curl_flags = get_curl_flags() or {}

  vim.iter(headers):each(function(header)
    vim.list_extend(cmd, { "-H", header })
  end)

  vim.list_extend(cmd, curl_flags)
  vim.list_extend(cmd, { "-d", body, url })

  local request = Shell.run(cmd, { err_msg = "Request error", abort_on_stderr = true }, function(system)
    Logger.debug("Executed request: " .. request_desc .. "\n" .. vim.inspect(system))
    vim.schedule(function()
      Async.co_resume(co, system)
    end)
  end)

  local debug_msg = { "Executing request: " .. request_desc, "Url: " .. url, "Payload: " .. body }
  _ = #headers > 0 and table.insert(debug_msg, "Headers: " .. vim.inspect(headers))

  Logger.debug(table.concat(debug_msg, "\n"))

  if not request then return end

  local status, response = Async.co_yield(co, request_timeout)
  Logger.debug("Response: " .. vim.inspect(response))

  if not status then return Logger.error("Request failed: " .. request_desc) end
  if response == "timeout" then return Logger.error("Request timeout: " .. request_desc) end

  local out = response.stdout == "" and "{}" or response.stdout

  local result, error = Json.parse(out)
  if not result then error = "Error parsing authentication response: " .. tostring(out) .. "\n" .. error end

  if result and result.error and result.error ~= "authorization_pending" then
    error = result.error .. "\n" .. (result.error_description or "")
  end
  if error then return Logger.error("Failed to: " .. request_desc .. ". " .. error, 2), error end

  return result
end

local function parse_variables(config, env)
  local parser = require("kulala.parser.string_variables_parser")

  vim.iter(config):each(function(key, value)
    if type(value) == "string" then
      config[key] = parser.parse(value, {}, env, false)
    elseif type(value) == "table" then
      config[key] = parse_variables(value, env)
    end
  end)

  return config
end

---@return table - get the auth config for the current environment, under Security.Auth
local function get_auth_config(config_id)
  local env = Async.co_wrap(co, function()
    return Env.get_env() or {}
  end) or {}

  local auth_config = vim.tbl_get(env, "Security", "Auth", config_id) or {}
  auth_config = parse_variables(auth_config, env)

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
  Async.co_wrap(co, Env.update_http_client_auth, config_id, auth_data)
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
  config = update_auth_data(config_id, config.auth_data, true)

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

local function add_client_credentials(config_id, body, headers)
  local config = get_auth_config(config_id)
  local type = config["Client Credentials"] or "basic"

  headers = headers or {}
  if type == "none" then return body, headers end

  local required_params = { "Client ID", "Client Secret" }
  if not validate_auth_params(config_id, required_params) then return body, headers end

  if type == "basic" then
    local id, secret = vim.uri_encode(config["Client ID"]), vim.uri_encode(config["Client Secret"])
    table.insert(headers, "Authorization: Basic " .. Crypto.base64_encode(id .. ":" .. secret))
  end

  if type == "in body" then
    body = body .. "&client_id=" .. config["Client ID"] .. "&client_secret=" .. config["Client Secret"]
  end

  return body, headers
end

---Get custom headers
---@param config_id string
local function get_custom_headers(config_id)
  local config = get_auth_config(config_id)
  local headers = config["Custom Headers"] or {}

  return vim.iter(headers):fold({}, function(acc, key, value)
    return vim.list_extend(acc, { key .. ": " .. value })
  end)
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

  local headers = get_custom_headers(config_id)
  local url = config["Device Auth URL"]
  local body = "client_id=" .. config["Client ID"]

  body = config["Scope"] and body .. "&scope=" .. config["Scope"] or body
  body, headers = add_client_credentials(config_id, body, headers)
  body = add_custom_params(config_id, body, "In Auth Request")

  Logger.info("Acquiring device code for config: " .. config_id)

  local out = make_request(url, body, "acquire device code", { headers = headers })
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

  Logger.info("Verification code: " .. config.auth_data.user_code .. " is copied to clipboard")
  vim.fn.setreg("+", config.auth_data.user_code)
end

local function poll_token_server(config, url, body, headers)
  local auth = config.auth_data
  local interval = auth.interval and tonumber(auth.interval) * 1000 or request_interval
  local tries = 10

  Logger.info("Waiting for device token")

  local out, err
  for count = 1, tries do
    Async.co_sleep(co, interval)

    out, err = make_request(url, body, "acquire device token", { headers = headers })
    err = err or ""

    if not out and not err:match("authorization_pending") and not err:match("slow_down") then break end
    out = out or {}

    if out.access_token or exit or count == tries or os.difftime(os.time(), auth.acquired_at) > auth.expires_in then
      break
    end
  end

  return out
end

---Grant Type "Device Authorization"
---Acquire a device token for the given config_id
M.acquire_device_token = function(config_id)
  local device_code = M.get_device_code(config_id)
  local config = get_auth_config(config_id)

  local required_params = { "Grant Type", "Client ID", "Token URL" }
  if not device_code or not validate_auth_params(config_id, required_params) then return end

  M.verify_device_code(config_id)

  local headers = get_custom_headers(config_id)
  local url = config["Token URL"]
  local body = "client_id="
    .. config["Client ID"]
    .. "&device_code="
    .. device_code
    .. "&grant_type=urn:ietf:params:oauth:grant-type:device_code"

  body = config["Client Secret"] and body .. "&client_secret=" .. config["Client Secret"] or body
  body, headers = add_client_credentials(config_id, body, headers)
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Acquiring device token for config: " .. config_id)

  local out = poll_token_server(config, url, body, headers) or {}
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

  if not (url:find("localhost") or url:find("127.0.0.1") or config["Browser CMD"]) then
    local code = vim.uri_decode(vim.fn.input("Enter the Auth code/token: "))

    update_auth_data(config_id, {
      code = code,
      expires_in = config["Expires In"] or 10, -- to allow for resuming requests with new token
    })

    return code
  end

  local port = url:match(":(%d+)") or 8080

  tcp_server = Tcp.server("127.0.0.1", port, function(request)
    local params = parse_params(request) or {}

    if params.code or params.access_token then
      params.expires_in = params.expires_in or config["Expires In"] or 10 -- to allow for resuming requests with new token

      vim.schedule(function()
        update_auth_data(config_id, params)
        Async.co_resume(co, params.code or params.access_token)
      end)

      return "Code/Token received.  You can close the browser now."
    end
  end)

  if not tcp_server then return end

  Logger.info("Waiting for authorization code/token")

  local _, result = Async.co_yield(co, request_timeout)
  if not result or result == "timeout" then
    _ = tcp_server and tcp_server:stop()
    return Logger.error("Timeout waiting for authorization code/token for: " .. config_id)
  end

  return result
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

  payload.iat = jwt.payload.iat or os.time()
  payload.exp = jwt.payload.exp or jwt.payload.iat + 50

  return Crypto.jwt_encode(header, payload, config.private_key or config["Client Secret"])
end

---Grant Type "Client Credentials"
---Acquire a token using the client credentials for the given config_id
M.acquire_jwt_token = function(config_id)
  local config = get_auth_config(config_id)
  local assertion = config.Assertion or M.create_JWT(config_id)

  if not assertion or not validate_auth_params(config_id, { "Grant Type", "Token URL" }) then return end

  local headers = get_custom_headers(config_id)
  local url = config["Token URL"]
  local body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" .. assertion

  body, headers = add_client_credentials(config_id, body, headers)
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Acquiring token for config: " .. config_id)

  local out = make_request(url, body, "acquire token", { headers = headers })
  if not out then return end

  out.acquired_at = os.time()
  out.expires_in = out.expires_in or config["Expires In"] or 10 -- to allow for resuming requests with new token
  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

---Grant Type "Client Credentials"
---Acquire a token using the client credentials for the given config_id
M.acquire_client_credentials = function(config_id)
  local config = get_auth_config(config_id)
  local type = config["Client Credentials"] or "basic"

  if type == "jwt" then return M.acquire_jwt_token(config_id) end

  local required_params = { "Client ID", "Client Secret", "Token URL" }
  if not validate_auth_params(config_id, required_params) then return end

  local headers = get_custom_headers(config_id)
  local url = config["Token URL"]
  local body = "grant_type=client_credentials"

  body = config["Scope"] and body .. "&scope=" .. config["Scope"] or body
  body, headers = add_client_credentials(config_id, body, headers)
  body = add_custom_params(config_id, body, "In Auth Request")

  Logger.info("Acquiring token for config: " .. config_id)

  local out = make_request(url, body, "acquire token", { headers = headers })
  if not out then return end

  out.acquired_at = os.time()
  out.expires_in = out.expires_in or config["Expires In"] or 10 -- to allow for resuming requests with new token

  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

local function launch_browser(cmd, auth_url, redirect_url)
  local status, error
  local browser_cmd = {}

  cmd = cmd or ""

  if cmd == "" then
    browser_cmd = { "system default browser" }
    status, error = vim.ui.open(auth_url)
  else
    cmd = vim.split(cmd, " ")
    browser_cmd = { Fs.get_file_path(cmd[1]), auth_url, redirect_url or "http://localhost:80" }

    Logger.info("Launching browser with command: " .. vim.inspect(browser_cmd))
    status, error = Shell.run(browser_cmd, { err_msg = "Error launching browser" })
  end

  if not status then
    return Logger.error("Failed to open browser: " .. vim.inspect(browser_cmd) .. " " .. (error or ""))
  end

  return true
end

---Grant Type "Authorization Code" or "Implicit"
---Acquire an auth code for the given config_id
M.acquire_auth = function(config_id)
  local config = get_auth_config(config_id)

  local required_params = { "Grant Type", "Client ID", "Redirect URL", "Auth URL" }
  if not validate_auth_params(config_id, required_params) then return end

  local headers = get_custom_headers(config_id)
  local url = config["Auth URL"]
  local body = "redirect_uri=" .. config["Redirect URL"] .. "&client_id=" .. config["Client ID"]

  local response_type = config["Grant Type"] == "Authorization Code" and "code" or "token"
  response_type = config["Response Type"] or response_type

  body = body .. "&response_type=" .. response_type
  body = config["Scope"] and body .. "&scope=" .. config["Scope"] or body

  body = add_pkce(config_id, body, "auth")
  body, headers = add_client_credentials(config_id, body, headers)
  body = add_custom_params(config_id, body, "In Auth Request")

  local uri = url .. "?" .. body

  Logger.info("Acquiring code for config: " .. config_id)
  Logger.debug("Auth URL: " .. uri)

  if not launch_browser(config["Browser CMD"], uri, config["Redirect URL"]) then return end

  local code = M.receive_code(config_id)
  if not code then return Logger.error("Failed to acquire code for config: " .. config_id) end

  Logger.info("Authorization code/token acquired for config: " .. config_id)
  config = update_auth_data(config_id, { code = code, acquired_at = os.time() })

  return code
end

M.acquire_password_token = function(config_id)
  local config = get_auth_config(config_id)
  local required_params = { "Client ID", "Client Secret", "Token URL", "Username", "Password" }
  if not validate_auth_params(config_id, required_params) then return end

  local headers = get_custom_headers(config_id)
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

  body, headers = add_client_credentials(config_id, body, headers)
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Acquiring token for config: " .. config_id)

  local out = make_request(url, body, "acquire token", { headers = headers })
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

  Table.remove_keys(
    config.auth_data,
    { "code", "device_code", "user_code", "access_token", "id_token", "refresh_token" }
  )
  config = update_auth_data(config_id, config.auth_data, true)

  if config["Grant Type"] == "Device Authorization" then return M.acquire_device_token(config_id) end
  if config["Grant Type"] == "Client Credentials" then return M.acquire_client_credentials(config_id) end
  if config["Grant Type"] == "Password" then return M.acquire_password_token(config_id) end

  local code = M.acquire_auth(config_id)
  if config["Grant Type"] == "Implicit" then return code end

  local required_params = { "Client ID", "Redirect URL", "Token URL" }
  if not code or not validate_auth_params(config_id, required_params) then return end

  local url = config["Token URL"]
  local headers = get_custom_headers(config_id)
  local body = "client_id="
    .. config["Client ID"]
    .. "&code="
    .. code
    .. "&redirect_uri="
    .. config["Redirect URL"]
    .. "&grant_type=authorization_code"

  body = config["Client Secret"] and body .. "&client_secret=" .. config["Client Secret"] or body

  body = add_pkce(config_id, body, "token")
  body, headers = add_client_credentials(config_id, body, headers)
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Acquiring new token for config: " .. config_id)

  local out = make_request(url, body, "acquire token", { headers = headers })
  if not out then return end

  Logger.debug("Token acquired for config: " .. config_id)
  out.acquired_at = os.time()

  if out.refresh_token then
    out.refresh_token_acquired_at = os.time()
    Logger.debug("Refresh Token acquired for config: " .. config_id)
  end

  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

---Grant Type "Authorization Code" or "Device Authorization"
---Refresh the token for the given config_id
local function refresh_token_co(config_id)
  if not validate_auth_params(config_id, { "Grant Type" }) then return end

  local config = get_auth_config(config_id)

  local refresh_token = not M.is_token_expired(config_id, "refresh_token") and config.auth_data.refresh_token
  if not refresh_token then return M.acquire_token(config_id) end

  if not validate_auth_params(config_id, { "Client ID", "Token URL" }) then return end

  local headers = get_custom_headers(config_id)
  local url = config["Token URL"]
  local body = "client_id=" .. config["Client ID"] .. "&refresh_token=" .. refresh_token .. "&grant_type=refresh_token"

  body = config["Client Secret"] and body .. "&client_secret=" .. config["Client Secret"] or body
  body, headers = add_client_credentials(config_id, body, headers)
  body = add_custom_params(config_id, body, "In Token Request")

  Logger.info("Refreshing token for config: " .. config_id)

  local out = make_request(url, body, "refresh token", { headers = headers })
  if not out then return end

  out.acquired_at = os.time()
  config = update_auth_data(config_id, out)

  return config.auth_data.access_token
end

local function run_auth_async(config_id, fn)
  local buf = DB.current_buffer
  local progress = Float.create_progress_float("Acquiring auth data.  Press <C-c> to cancel.")

  co = coroutine.create(function()
    vim.keymap.set("n", "<C-c>", function()
      progress.hide()
      Logger.info("Cancelling token acquisition for config: " .. config_id)

      Async.co_resume(co)
      tcp_server = tcp_server and tcp_server:stop()
      exit = true

      vim.keymap.del("n", "<C-c>", { buffer = buf })
    end, { buffer = buf, nowait = true })

    fn()

    progress.hide()
    co, exit = nil, nil
  end)

  Async.co_resume(co)
end

M.refresh_token = function(config_id)
  local Cmd = require("kulala.cmd")
  Cmd.queue:pause()

  run_auth_async(config_id, function()
    if refresh_token_co(config_id) then
      Cmd.queue:resume()
    elseif Cmd.queue.previous_task then
      vim.schedule(function()
        Inlay.show(DB.current_buffer, "error", Cmd.queue.previous_task.data.request.show_icon_line_number)
      end)
    end
  end)
end

M.refresh_token_manually = function(config_id)
  run_auth_async(config_id, function()
    if refresh_token_co(config_id) then
      Logger.info("Token refreshed for config: " .. config_id)
    else
      Logger.error("Failed to refresh token for config: " .. config_id)
    end
  end)
end

M.acquire_token_manually = function(config_id)
  run_auth_async(config_id, function()
    if M.acquire_token(config_id) then
      Logger.info("Token acquired for config: " .. config_id)
    else
      Logger.error("Failed to acquire token for config: " .. config_id)
    end
  end)
end

---Grant Type - all
---Entry point to get the token for the given config_id
M.get_token = function(type, config_id)
  if not config_id then return Logger.error("Auth config key not found.") end

  local config = get_auth_config(config_id)

  local token_type = (type == "idToken" or config["Use ID Token"]) and "id_token" or "access_token"
  token_type = config["Grant Type"] == "Implicit" and "code" or token_type

  local token = not M.is_token_expired(config_id) and config.auth_data[token_type]

  if config["Acquire Automatically"] == false then
    return token
      or Logger.info("`Acquire Automatically = false`\nNo valid access/refresh token for config: " .. config_id)
  end

  if not token then M.refresh_token(config_id) end

  return config.auth_data[token_type]
end

---Revoke the token for the given config_id
M.revoke_token = function(config_id)
  local config = get_auth_config(config_id)

  local token = config.auth_data.access_token
  if not token then return Logger.info("No token to revoke for config: " .. config_id) end

  local body = "token="
    .. config.auth_data.access_token
    .. "&client_id="
    .. config["Client ID"]
    .. "&client_secret="
    .. config["Client Secret"]

  Logger.info("Revoking token for config: " .. config_id)

  if validate_auth_params(config_id, { "Revoke URL" }) then
    co = coroutine.create(function()
      if make_request(config["Revoke URL"], body, "revoke token") then
        Logger.info("Token revoked for config: " .. config_id)
      end
    end)

    Async.co_resume(co)
  end

  Table.remove_keys(config.auth_data, {
    "code",
    "pkce_verifier",
    "access_token",
    "id_token",
    "refresh_token",
    "acquired_at",
    "expires_in",
    "refresh_token_acquired_at",
    "refresh_token_expires_in",
  })
  update_auth_data(config_id, config.auth_data, true)
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

M.auth_template = function()
  return {
    ["Type"] = "OAuth2",
    ["Acquire Automatically"] = true,
    ["Grant Type"] = {
      "Authorization Code",
      "Client Credentials",
      "Device Authorization",
      "Implicit",
      "Password",
    },
    ["Use ID Token"] = false,
    ["Client ID"] = "",
    ["Client Secret"] = "",
    ["Auth URL"] = "",
    ["Token URL"] = "",
    ["Device Auth URL"] = "",
    ["Redirect URL"] = "",
    ["Revoke URL"] = "",
    ["Expires In"] = "",
    ["Scope"] = "",
    ["Custom Headers"] = {
      ["my-custom-header"] = "my-custom-value",
    },
    ["Custom Request Parameters"] = {
      ["my-custom-parameter"] = "my-custom-value",
      ["access_type"] = {
        ["Value"] = "offline",
        ["Use"] = "In Auth Request",
      },
      ["audience"] = {
        ["Use"] = "In Token Request",
        ["Value"] = "https://my-audience.com/",
      },
      ["usage"] = {
        ["Use"] = "In Auth Request",
        ["Value"] = "https://my-usage.com/",
      },
      ["resource"] = {
        "https =//my-resource/resourceId1",
        "https =//my-resource/resourceId2",
      },
    },
    ["Username"] = "",
    ["Password"] = "",
    ["Client Credentials"] = {
      "none",
      "in body",
      "basic",
      "jwt",
    },
    ["PKCE"] = {
      true,
      {
        ["Code Challenge Method"] = {
          "Plain",
          "SHA-256",
        },
        ["Code Verifier"] = "YYLzIBzrXpVaH5KRx86itubKLXHNGnJBPAogEwkhveM",
      },
    },
    ["JWT"] = {
      header = {
        alg = "RS256",
        typ = "JWT",
      },
      payload = {
        ia = 0,
        exp = 50,
      },
    },
  }
end
return M
