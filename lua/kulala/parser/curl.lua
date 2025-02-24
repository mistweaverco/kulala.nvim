local Config = require("kulala.config")
local Shlex = require("kulala.lib.shlex")
local Stringutils = require("kulala.utils.string")

local M = {}

---Parse a curl command into a Request object
---@param curl string The curl command line to parse
---@return Request|nil -- Table with a parsed data or nil if parsing fails
---@return string|nil -- Original curl command (sanitized one-liner) or nil if parsing fails
function M.parse(curl)
  if not curl or #curl == 0 then return end

  -- Combine multi-line curl commands into a single line.
  -- Good for everyone, but especially for
  -- Googlers who copy curl commands from their beloved ❤️ Google Chrome DevTools.
  --
  -- This is a simple heuristic that assumes that a backslash followed by a newline
  -- is a line continuation. This is not always true, but it's good enough for most cases.
  -- It should also work with Windows-style line endings.
  -- If you have a better idea, please submit a PR.
  curl = curl:gsub("\\\r?\n", "")

  -- remove extra spaces,
  -- they confuse the Shlex parser and might be present in the output of the above heuristic
  curl = curl:gsub("%s+", " ")

  local parts = Shlex.split(curl)
  if not parts[1]:find("^curl.*") and parts[1] ~= Config.get().curl_path then return end

  local command = {
    method = "",
    headers = {},
    cookie = "",
    data = nil,
    url = "",
    http_version = "",
    body = {},
    previous_flag = nil,
  }

  local curl_flags = {
    { "-X", "--request", "method" },
    { "-A", "--user-agent", "user-agent" },
    { "-b", "--cookie", "cookie" },
    { "-H", "--header", "headers" },
    { "-d", "--data", "--data-raw", "--json", "body" },
  }

  local function set_header(headers, header, value)
    headers[Stringutils.remove_extra_space(header:lower())] = Stringutils.remove_extra_space(value)
  end

  local function parse_flag(cmd, part)
    local flags = vim.iter(curl_flags):find(function(flags)
      return vim.tbl_contains(flags, part)
    end)

    cmd.previous_flag = flags and flags[#flags] or nil

    if part:match("--http") then
      cmd.http_version = "HTTP/" .. part:match("[%d%.]+") -- 1.1
    elseif part == "--json" then
      set_header(cmd.headers, "content-type", "application/json")
      set_header(cmd.headers, "accept", "application/json")
    end

    return true
  end

  local function parse_flag_value(cmd, part)
    local flag = cmd.previous_flag
    if part:match("curl") then
      -- skip
    elseif part:match("^[a-z0-9]+://") and cmd.url == "" then
      cmd.url = part
    elseif flag == "headers" then
      set_header(cmd.headers, Stringutils.cut(part, ":"))
    elseif flag == "user-agent" then
      set_header(cmd.headers, "user-agent", part)
    elseif flag == "body" then
      table.insert(cmd.body, part)
    else
      cmd[flag or ""] = part
    end
  end

  local cmd = vim.iter(parts):fold(command, function(cmd, part)
    _ = part:match("^%-") and parse_flag(cmd, part) or parse_flag_value(cmd, part)
    return cmd
  end)

  _ = #cmd.body > 0
    and not cmd.headers["content-type"]
    and set_header(cmd.headers, "content-type", "application/x-www-form-urlencoded")

  cmd.method = #cmd.method > 0 and cmd.method or (#cmd.body > 0 and "POST" or "GET")

  return cmd, curl
end

return M
