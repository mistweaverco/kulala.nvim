local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")
local Logger = require("kulala.logger")

local M = {}

---Base64 encode the input string (standard encoding for OAuth2 Basic auth)
---@param input string
---@return string
M.base64_encode_standard = function(input)
  local value, err = KULALA_CORE.crypto("base64_encode_standard", { input = input })
  if err then
    Logger.error("base64_encode_standard failed: " .. err)
    return ""
  end
  return value or ""
end

---Base64url encode (Neovim built-in; used for display helpers)
---@param input string
---@return string
M.base64_encode = function(input)
  return (vim.base64.encode(input):gsub("+", "-"):gsub("/", "_"):gsub("=+$", ""))
end

---@return string|nil
M.pkce_verifier = function()
  local value, err = KULALA_CORE.crypto("pkce_verifier", {})
  if err then
    Logger.error("Failure to generate PKCE verifier: " .. err)
    return nil
  end
  return value
end

---@param verifier string
---@param method string|nil
---@return string|nil
M.pkce_challenge = function(verifier, method)
  method = method or "S256"
  local value, err = KULALA_CORE.crypto("pkce_challenge", {
    verifier = verifier,
    method = method,
  })
  if err then
    Logger.error("Failure to generate PKCE challenge: " .. err)
    return nil
  end
  return value
end

---@class JWTPayload
---@field iss? string
---@field sub? string
---@field scope? string
---@field aud? string
---@field exp? number
---@field iat? number

---@param header {alg: string, typ: string}
---@param payload JWTPayload
---@param key string
---@return string|nil
M.jwt_encode = function(header, payload, key)
  local value, err = KULALA_CORE.crypto("jwt_encode", {
    header = header,
    payload = payload,
    key = key,
  })
  if err then
    Logger.error("Failure to encode JWT: " .. err)
    return nil
  end
  return value
end

return M
