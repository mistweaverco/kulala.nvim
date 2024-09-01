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
    method = "GET",
    headers = {},
    data = nil,
    url = parts[#parts],
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
      if arg == "-X" then
        state = State.Method
      elseif arg == "-A" then
        state = State.UserAgent
      elseif arg == "-H" then
        state = State.Header
      elseif arg == "--data" then
        state = State.Body
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

  return res
end

return M
