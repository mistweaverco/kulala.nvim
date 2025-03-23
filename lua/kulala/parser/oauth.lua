local Config = require("kulala.config")
local DB = require("kulala.db")
local Env = require("kulala.parser.env")
local Logger = require("kulala.logger")
local table = require("kulala.utils.table")

local M = {}

---@param url string
---@param body string
---@param request_type string - description of the request
---@return table|nil
local function request(url, body, request_type)
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
  local env = Env.get_env()
  return vim.tbl_get(env, "Security", "Auth", config_id) or {}
end

local function validate_auth_params(config_id, keys)
  local config = get_auth_config(config_id)

  vim.iter(keys):each(function(key)
    if not config[key] then
      return Logger.error("Missing required field [" .. key .. "] in the Auth config: " .. config_id)
    end
  end)

  return true
end

local function update_auth_config(config_id, update)
  local config = vim.tbl_extend("force", get_auth_config(config_id), update)
  Env.update_http_client_auth(config_id, config)
  Env.get_env()

  return config
end

M.acquire_code = function(config_id)
  local config = get_auth_config(config_id)
  if not validate_auth_params(config_id, { "client_id", "redirect_uris", "auth_uri" }) then return end

  local url = config["auth_uri"]
  local body = "scope="
    .. vim.uri_encode(config["scope"])
    .. "&access_type=offline"
    .. "&include_granted_scopes=true"
    .. "&response_type=code"
    .. "&redirect_uri="
    .. config["redirect_uris"][1]
    .. "&client_id="
    .. config["client_id"]

  -- state=state_parameter_passthrough_value& -- TODO: add optional parameters to request

  local uri = url .. "?" .. body

  Logger.info("Acquiring code for config: " .. config_id)
  vim.ui.open(uri)

  return vim.uri_decode(vim.fn.input("Enter the auth code: "))
end

M.acquire_token = function(config_id)
  local config = get_auth_config(config_id)
  local code = M.acquire_code(config_id)

  if not validate_auth_params(config_id, { "client_id", "client_secret", "redirect_uris", "token_uri" }) then return end

  local url = config["token_uri"]
  local body = "client_id="
    .. config["client_id"]
    .. "&client_secret="
    .. config["client_secret"]
    .. "&code="
    .. code
    .. "&redirect_uri="
    .. config["redirect_uris"][1]
    .. "&grant_type=authorization_code"

  Logger.info("Acquiring new token for config: " .. config_id)

  local out = request(url, body, "acquire token")
  if not out then return end

  out.acquired_at = os.time()
  out.refresh_token_acquired_at = os.time()

  config = update_auth_config(config_id, out)

  return config["access_token"]
end

M.refresh_token = function(config_id)
  local config = get_auth_config(config_id)
  local refresh_token = not M.is_token_expired(config_id, "refresh_token") and config["refresh_token"]
  if not refresh_token then return M.acquire_token(config_id) end

  if not validate_auth_params(config_id, { "client_id", "client_secret", "token_uri" }) then return end

  local url = config["token_uri"]
  local body = "client_id="
    .. config["client_id"]
    .. "&client_secret="
    .. config["client_secret"]
    .. "&refresh_token="
    .. refresh_token
    .. "&grant_type=refresh_token"

  Logger.info("Refreshing token for config: " .. config_id)

  local out = request(url, body, "refresh token")
  if not out then return end

  out.acquired_at = os.time()
  config = update_auth_config(config_id, out)

  return config["access_token"]
end

M.get_token = function(config_id)
  -- M.test()
  local config = get_auth_config(config_id)

  local token = not M.is_token_expired(config_id) and config["access_token"]
  return token or M.refresh_token(config_id)
end

M.revoke_token = function(config_id)
  -- M.test()
  local config = get_auth_config(config_id)

  local token = config["access_token"]
  if not token then return end

  local url = config["revoke_uri"]
  local body = "token=" .. config["access_token"]

  Logger.info("Revoking token for config: " .. config_id)

  request(url, body, "revoke token")

  table.remove_keys(config, {
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
  -- M.test()
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

return M
