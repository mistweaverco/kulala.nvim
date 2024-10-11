--- This class is used to manage the HTTP headers
--- HTTP header has a case-insensitive name - so class store it in a lower case
--- and can have a multiple values - which are stored in a table
---@class HTTPHeaders
---@field _headers table<string, string[]> - internal table storing the HTTP headers
local HTTPHeaders = {}

--- new creates a new instance of HTTPHeaders
---@return HTTPHeaders
function HTTPHeaders.new()
  return setmetatable({ _headers = {} }, HTTPHeaders)
end

--- has checks if a given name exists
---@param self HTTPHeaders
---@param key string
---@return boolean
function HTTPHeaders.has(self, key)
  return self._headers[key:lower()] ~= nil
end

--- has checks if a given name exists and contains a specific value
---@param self HTTPHeaders
---@param key string
---@param value string
---@return boolean
function HTTPHeaders.has_value(self, key, value)
  if not self:has(key) then
    return false
  end
  for _, v in ipairs(self._headers[key:lower()]) do
    if v == value then
      return true
    end
  end
  return false
end

---@param self HTTPHeaders
---@param key string
---@return any
function HTTPHeaders.__index(self, key)
  return rawget(getmetatable(self), key) or rawget(self._headers, key:lower())
end

---@param self HTTPHeaders
---@param key string
---@param value string
function HTTPHeaders.__newindex(self, key, value)
  local values = rawget(self._headers, key:lower()) or {}
  values[#values + 1] = value
  rawset(self._headers, key:lower(), values)
end

--- flatpairs returns a pair of a name, single-value, where names are repeated
---@param self HTTPHeaders
---@return function
---@return HTTPHeaders
---@return nil
function HTTPHeaders.flatpairs(self)
  local co = coroutine.create(function()
    for key, values in pairs(self._headers) do
      for _, value in ipairs(values) do
        coroutine.yield(key, value)
      end
    end
  end)
  local idx = 0
  ---@return integer|nil
  ---@return string[]|nil
  local next = function(_, _)
    local key, value
    repeat
      _, key, value = coroutine.resume(co)
      idx = idx + 1
      if key == nil then
        return nil, nil
      end
      return idx, { key, value }
    until key ~= nil
  end
  return next, self, nil
end

return HTTPHeaders
