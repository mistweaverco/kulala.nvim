---@diagnostic disable: undefined-field
local Config = require("kulala.config")
local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")

local M = {}

local function base64_encode(input)
  return vim.base64.encode(input):gsub("+", "-"):gsub("/", "_"):gsub("=", "")
end

local function openssl_path()
  return Config.get().openssl_path or "openssl"
end

M.pkce_verifier = function()
  local err_msg = "Failure to generate PKCE verifier: "

  local output_file = os.tmpname()
  local cmd = ("%s rand -out %s 32"):format(openssl_path(), output_file)

  local ret = os.execute(cmd)
  if ret ~= 0 then return Logger.error(err_msg .. "failed to generate random bytes") end

  local verifier = Fs.read_file(output_file, true)
  os.remove(output_file)

  if not verifier then return Logger.error(err_msg .. "failed to read random bytes") end

  return base64_encode(verifier)
end

M.pkce_challenge = function(verifier, method)
  method = method or "S256"

  if method == "PLAIN" then return verifier end
  if method ~= "S256" then return Logger.error("Unsupported PKCE method: " .. method) end

  local err_msg = "Failure to generate PKCE challenge: "

  local input_file = os.tmpname()
  if not Fs.write_file(input_file, verifier, true) then return Logger.error(err_msg .. "failed to open temp file") end

  local output_file = os.tmpname()
  local cmd = ("%s dgst -sha256 -binary -out %s %s"):format(openssl_path(), output_file, input_file)

  local ret = os.execute(cmd)
  if ret ~= 0 then
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

  return base64_encode(hash)
end

M.jwt_encode = function(header, payload, key)
  local err_msg = "Failure to encode JWT: "

  local digest = header.digest or "sha256"
  header.digest = nil

  -- Base64url encode the header and payload
  local header_b64 = base64_encode(vim.json.encode(header))
  local payload_b64 = base64_encode(vim.json.encode(payload))

  -- Save the signing input to a temp file
  local signing_input = header_b64 .. "." .. payload_b64
  local input_file = os.tmpname()
  if not Fs.write_file(input_file, signing_input, true) then
    return Logger.error(err_msg .. "failed to open temp file")
  end

  -- Save the key to a temp file
  local key_file = os.tmpname()
  if not Fs.write_file(key_file, key, true) then
    return Logger.report_error(err_msg .. "failed to write key temp file")
  end

  -- Sign with OpenSSL
  local signature_file = os.tmpname()
  local cmd = ("%s dgst -%s -sign %s -out %s %s"):format(openssl_path(), digest, key_file, signature_file, input_file)

  local ret = os.execute(cmd)
  if ret ~= 0 then return Logger.error(err_msg .. "failed to sign with OpenSSL") end

  -- Read the signature
  local signature = Fs.read_file(signature_file, true)
  if not signature then return Logger.error(err_msg .. "failed to read signature") end

  -- Clean up temp files
  os.remove(input_file)
  os.remove(key_file)
  os.remove(signature_file)

  if not signature then return Logger.error(err_msg .. "failed to read signature") end

  return signing_input .. "." .. base64_encode(signature)
end

return M
