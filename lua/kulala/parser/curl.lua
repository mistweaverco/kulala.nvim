local Config = require("kulala.config")
local Shlex = require("kulala.lib.shlex")
local Stringutils = require("kulala.utils.string")

local M = {}

---Parse a curl command into a Request object
---@param curl string The curl command line to parse
---@return Request|nil -- Table with a parsed data or nil if parsing fails
---@return string|nil -- Original curl command (sanitized one-liner) or nil if parsing fails
function M.parse(curl)
  if curl == nil or string.len(curl) == 0 then return nil, nil end

  -- Combine multi-line curl commands into a single line.
  -- Good for everyone, but especially for
  -- Googlers who copy curl commands from their beloved ❤️ Google Chrome DevTools.
  --
  -- This is a simple heuristic that assumes that a backslash followed by a newline
  -- is a line continuation. This is not always true, but it's good enough for most cases.
  -- It should alsow work with Windows-style line endings.
  -- If you have a better idea, please submit a PR.
  curl = string.gsub(curl, "\\\r?\n", "")

  -- remove extra spaces,
  -- they confuse the Shlex parser and might be present in the output of the above heuristic
  curl = string.gsub(curl, "%s+", " ")

  local parts = Shlex.split(curl)
  -- if string doesn't start with curl or different from curl_path, return nil
  -- it could also be curl-7.68.0 or something like that
  if string.find(parts[1], "^curl.*") == nil and parts[1] ~= Config.get().curl_path then return nil, nil end
  local res = {
    method = "",
    headers = {},
    data = nil,
    url = "",
    http_version = "",
    body = {},
  }

  local State = {
    START = 0,
    Method = 1,
    UserAgent = 2,
    Header = 3,
    Body = 4,
  }
  local state = State.START

  local function set_header(headers, header, value)
    headers[header:lower()] = value
  end

  for _, arg in ipairs(parts) do
    local skip = false
    if state == State.START then
      if arg:match("^[a-z0-9]+://") and res.url == "" then
        res.url = arg
      elseif arg == "-X" or arg == "--request" then
        state = State.Method
      elseif arg == "-A" or arg == "--user-agent" then
        state = State.UserAgent
      elseif arg == "-H" or arg == "--header" then
        state = State.Header
      elseif arg == "-d" or string.match(arg, "--data") then
        state = State.Body

        if not res.headers["content-type"] then
          set_header(res.headers, "content-type", "application/x-www-form-urlencoded")
        end

        res.method = res.method == "" and "POST" or res.method
      elseif arg == "--json" then
        state = State.Body
        set_header(res.headers, "content-type", "application/json")
        set_header(res.headers, "accept", "application/json")
        res.method = res.method == "" and "POST" or res.method
      elseif arg == "--http1.1" then
        res.http_version = "HTTP/1.1"
      elseif arg == "--http2" then
        res.http_version = "HTTP/2"
      elseif arg == "--http3" then
        res.http_version = "HTTP/3"
      end
      skip = true
    end

    if not skip then
      if state == State.Method then
        res.method = arg
      elseif state == State.UserAgent then
        set_header(res.headers, "user-agent", arg)
      elseif state == State.Header then
        local header, value = Stringutils.cut(arg, ":")
        set_header(res.headers, Stringutils.remove_extra_space(header), Stringutils.remove_extra_space(value))
      elseif state == State.Body then
        table.insert(res.body, arg)
      end
    end

    if not skip then state = State.START end
  end

  if res.method == "" then res.method = "GET" end
  return res, curl
end

return M
