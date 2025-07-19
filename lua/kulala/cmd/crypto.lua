---@diagnostic disable: undefined-field
local Config = require("kulala.config")
local Fs = require("kulala.utils.fs")
local Json = require("kulala.utils.json")
local Logger = require("kulala.logger")

local M = {}

---Base64url encode the input string
---@param input string Input string to be encoded
---@return string Base64url encoded string
M.base64_encode = function(input)
  return vim.base64.encode(input):gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
end

local function openssl_path()
  return Config.get().openssl_path or "openssl"
end

---Generate a random PKCE verifier
---@return string|nil PKCE verifier
M.pkce_verifier = function()
  local err_msg = "Failure to generate PKCE verifier: "

  local output_file = os.tmpname()
  local cmd = ("%s rand -out %s 32"):format(openssl_path(), output_file)

  local ret = os.execute(cmd)
  if not ret then return Logger.error(err_msg .. "failed to generate random bytes") end

  local verifier = Fs.read_file(output_file, true)
  os.remove(output_file)

  if not verifier then return Logger.error(err_msg .. "failed to read random bytes") end

  return M.base64_encode(verifier)
end

---Generate a PKCE challenge from the verifier
---@param verifier string PKCE verifier
---@param method string PKCE method "Plain"|"S256" (default: "S256")
---@return string|nil PKCE challenge
M.pkce_challenge = function(verifier, method)
  method = method or "S256"

  if method == "Plain" then return verifier end
  if method:lower() ~= "s256" then return Logger.error("Unsupported PKCE method: " .. method) end

  local err_msg = "Failure to generate PKCE challenge: "

  local input_file = os.tmpname()
  if not Fs.write_file(input_file, verifier, true) then return Logger.error(err_msg .. "failed to open temp file") end

  local output_file = os.tmpname()
  local cmd = ("%s dgst -sha256 -binary -out %s %s"):format(openssl_path(), output_file, input_file)

  local ret = os.execute(cmd)
  if not ret then
    os.remove(input_file)
    return Logger.error(err_msg .. "failed to generate SHA256 hash")
  end

  local hash = Fs.read_file(output_file, true)
  if not hash then
    os.remove(input_file)
    return Logger.error(err_msg .. "failed to open hash output file")
  end

  os.remove(input_file)
  os.remove(output_file)

  return M.base64_encode(hash)
end

---@class JWTPayload
---@field iss? string Issuer
---@field sub? string Subject
---@field scope? string Scope
---@field aud? string Audience
---@field exp? number Expiration time (in seconds since epoch)
---@field iat? number Issued at (in seconds since epoch)

---Generate a JWT token
---@param header {alg: string, typ: string} JWT header alg: "RS256"|"HS256", typ: "JWT"
---@param payload JWTPayload JWT payload
---@param key string Signing key
---@return string|nil JWT token
M.jwt_encode = function(header, payload, key)
  local err_msg = "Failure to encode JWT: "
  local supported_alg = { "RS256", "HS256" }

  if not vim.tbl_contains(supported_alg, header.alg) then
    return Logger.error("Unsupported Algorithm: " .. header.alg)
  end
  local method = header.alg == "RS256" and "sign" or "hmac"

  -- Base64url encode the header and payload
  local header_b64 = M.base64_encode(Json.encode(header, { sort = true }):gsub("%s+", ""))
  local payload_b64 = M.base64_encode(Json.encode(payload, { sort = true }):gsub("%s+", ""))

  -- Save the signing input to a temp file
  local signing_input = header_b64 .. "." .. payload_b64
  local input_file = os.tmpname()

  if not Fs.write_file(input_file, signing_input, false, true) then
    return Logger.error(err_msg .. "failed to open temp file")
  end

  -- Save the key to a temp file
  local key_file = os.tmpname()
  if not Fs.write_file(key_file, key, false, true) then
    return Logger.error(err_msg .. "failed to write key temp file")
  end

  key_file = method == "sign" and key_file or '"' .. key .. '"'

  -- Sign with OpenSSL
  local signature_file = os.tmpname()
  local cmd = ("%s dgst -sha256 -%s %s -binary -out %s %s"):format(
    openssl_path(),
    method,
    key_file,
    signature_file,
    input_file
  )

  local ret = os.execute(cmd)
  if not ret then return Logger.error(err_msg .. "failed to sign with OpenSSL") end

  -- Read the signature
  local signature = Fs.read_file(signature_file, true)
  if not signature then return Logger.error(err_msg .. "failed to read signature") end

  -- Clean up temp files
  os.remove(input_file)
  os.remove(key_file)
  os.remove(signature_file)

  if not signature then return Logger.error(err_msg .. "failed to read signature") end

  return signing_input .. "." .. M.base64_encode(signature)
end

return M
