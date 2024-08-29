local Shlex = require("kulala.shlex")

local M = {}

---Parse a curl command into a Request object
---@param curl string The curl command line to parse
---@return Request|nil -- Table with a parsed data or nil if parsing fails
function M.parse(curl)
  if curl == nil or string.len(curl) == 0 then
    return nil
  end
  local parts = Shlex.split(curl)
  if string.find(parts[1], "^curl") == nil then
    return nil
  end
  local res = {
    method = "",
    headers = {},
    data = nil,
    url = "",
    http_version = "",
  }

  local State = {
    START = 0,
    Method = 1,
    UserAgent = 2,
    Header = 3,
    Body = 4,
  }
  local state = State.START

  for _, arg in ipairs(parts) do
    if state == State.START then
      if arg:match("^http[s]?://") and res.url == "" then
        res.url = arg
        goto continue
      elseif arg == "-X" or arg == "--request" then
        state = State.Method
      elseif arg == "-A" or arg == "--user-agent" then
        state = State.UserAgent
      elseif arg == "-H" or arg == "--header" then
        state = State.Header
      elseif arg == "-d" or arg == "--data" or arg == "--data-raw" then
        state = State.Body
        if res.method == "" then
          res.method = "POST"
        end
        if res.headers["content-type"] == nil then
          res.headers["content-type"] = "application/x-www-form-urlencoded"
        end
      elseif arg == "--http1.1" then
          res.http_version = "HTTP/1.1"
      elseif arg == "--http2" then
          res.http_version = "HTTP/2"
      elseif arg == "--http3" then
          res.http_version = "HTTP/3"
      end
      goto continue
    end

    if state == State.Method then
      res.method = arg
    elseif state == State.UserAgent then
      res.headers["user-agent"] = arg
    elseif state == State.Header then
      local header = string.match(arg, "^(.*):")
      local value = string.match(arg, ":(.*)$")
      res.headers[header] = value
    elseif state == State.Body then
      res.body = arg
    end
    state = State.START

    ::continue::
  end

  if res.method == "" then
    res.method = "GET"
  end
  return res
end

return M
