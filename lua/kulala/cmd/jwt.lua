---@diagnostic disable: undefined-field
local Config = require("kulala.config")
local Logger = require("kulala.logger")

local M = {}

M.encode = function(header, payload, key)
  local err_msg = "Failure to encode JWT: "

  local digest = header.digest or "sha256"
  header.digest = nil

  -- Base64url encode the header and payload
  local header_b64 = vim.base64.encode(vim.json.encode(header)):gsub("+", "-"):gsub("/", "_"):gsub("=", "")
  local payload_b64 = vim.base64.encode(vim.json.encode(payload)):gsub("+", "-"):gsub("/", "_"):gsub("=", "")

  -- Sace the signing input to a temp file
  local signing_input = header_b64 .. "." .. payload_b64

  local input_file = os.tmpname()
  local f = io.open(input_file, "w")
  if not f then return Logger.error(err_msg .. "failed to open temp file") end

  f:write(signing_input)
  f:close()

  -- Save the key to a temp file
  local key_file = os.tmpname()
  local kf = io.open(key_file, "w")
  if not kf then return Logger.report_error(err_msg .. "failed to open temp file") end

  kf:write(key)
  kf:close()

  -- Sign with OpenSSL
  local signature_file = os.tmpname()
  local cmd = string.format(
    "%s dgst -%s -sign %s -out %s %s",
    Config.get().openssl_path or "openssl",
    digest,
    key_file,
    signature_file,
    input_file
  )

  local ret = os.execute(cmd)
  if ret ~= 0 then return Logger.error(err_msg .. "failed to sign with OpenSSL") end

  -- Read the signature
  local sf = io.open(signature_file, "rb")
  local signature = sf:read("*all")
  sf:close()

  if not signature then return Logger.error(err_msg .. "failed to read signature") end

  -- Clean up temp files
  os.remove(input_file)
  os.remove(key_file)
  os.remove(signature_file)

  -- Base64url encode the signature
  local signature_b64 = vim.base64.encode(signature):gsub("+", "-"):gsub("/", "_"):gsub("=", "")

  return signing_input .. "." .. signature_b64
end

return M
