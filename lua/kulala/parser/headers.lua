--- This class is used to manage the HTTP headers
--- HTTP header has a case-insensitive name, so for set and lookup purposes those are stored in a lower-case
--- The original case is saved and returned via flatpairs method.
---@class HTTPHeaders
---@field _headers table<string, table> - internal table storing the HTTP headers
local HTTPHeaders = {}

--- new creates a new instance of HTTPHeaders
---@return HTTPHeaders
function HTTPHeaders.new()
  return setmetatable({ _headers = {} }, HTTPHeaders)
end

--- has checks if a given name exists and optional value, case insensitive
--- eg. headers.has("content-type") will match Content-Type too
--- eg. headers.has("content-type", "Text/plain") will match Content-Type, "text/plain"
---@param self HTTPHeaders
---@param name string
---@param value string|nil
---@return boolean
function HTTPHeaders.has(self, name, value)
  local key = name:lower()
  local exists = self._headers[key] ~= nil
  if value == nil then
    return exists
  end

  for _, e in ipairs(self._headers[key]) do
    if e.value:lower() == value:lower() then
      return true
    end
  end
  return false
end

--- has_exact checks if a given name exists, case sensitive
--- eg. headers.has("X-REQUEST-TYPE") won't match x-request-type
--- eg. headers.has("X-REQUEST-TYPE", "graphql") won't match x-request-type GRAPHQL
---@param self HTTPHeaders
---@param name string
---@param value string|nil
---@return boolean
function HTTPHeaders.has_exact(self, name, value)
  local key = name:lower()
  if value == nil then
    for _, e in ipairs(self._headers[key]) do
      if e.name == name then
        return true
      end
      return false
    end
  end

  for _, e in ipairs(self._headers[key]) do
    if e.name == name and e.value == value then
      return true
    end
  end
  return false
end

--- return a first value of a given name, case insensitive
--- eg. headers["content-type"]
--- use values() to get all values
---@param self HTTPHeaders
---@param name string
---@return any
function HTTPHeaders.__index(self, name)
  local key = name:lower()
  local ret = rawget(getmetatable(self), key)
  if ret ~= nil then
    return ret
  end
  ret = rawget(self._headers, key)
  if ret ~= nil then
    local values = {}
    for _, e in ipairs(ret) do
      values[#values + 1] = e.value
    end
    return values
  end
  return nil
end

--- append a new value to the header. The name is case insensitive and original casing is preserved
---@param self HTTPHeaders
---@param name string
---@param value string
function HTTPHeaders.__newindex(self, name, value)
  local key = name:lower()
  local values = rawget(self._headers, key) or {}
  values[#values + 1] = { name = name, value = value }
  rawset(self._headers, key, values)
end

--- flatpairs returns a pair of a name, single-value for all values. The original header name is returned
---@param self HTTPHeaders
---@return function
---@return HTTPHeaders
---@return nil
function HTTPHeaders.flatpairs(self)
  local co = coroutine.create(function()
    for _, values in pairs(self._headers) do
      for _, e in ipairs(values) do
        coroutine.yield(e.name, e.value)
      end
    end
  end)
  local idx = 0
  ---@return integer|nil
  ---@return string[]|nil
  local next = function(_, _)
    local name, value
    repeat
      _, name, value = coroutine.resume(co)
      idx = idx + 1
      if name == nil then
        return nil, nil
      end
      return idx, { name, value }
    until name ~= nil
  end
  return next, self, nil
end

return HTTPHeaders
