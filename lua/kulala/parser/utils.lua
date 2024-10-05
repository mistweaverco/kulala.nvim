local M = {}

-- PERF: we do a lot of if else blocks with repeating loops
-- we could "optimize" this by using a single loop and if else blocks
-- that would make the code more readable and easier to maintain
-- but it would also make it slower

---Check if a request has a specific meta tag
---@param request table The request to check
---@param tag string The meta tag to check for
M.contains_meta_tag = function(request, tag)
  tag = tag:lower()
  for _, meta in ipairs(request.metadata) do
    if meta.name:lower() == tag then
      return true
    end
  end
  return false
end

---Check if a header is present in the request
---@param headers table The headers to check
---@param header string The header name to check
---@param value string|nil The value to check for or nil if only the header name should be checked
---@return boolean
M.contains_header = function(headers, header, value)
  header = header:lower()
  value = value and value:lower() or nil
  if value == nil then
    for k, _ in pairs(headers) do
      if k:lower() == header then
        return true
      end
    end
  else
    for k, v in pairs(headers) do
      if k:lower() == header and v:lower() == value then
        return true
      end
    end
  end
  return false
end

---Get the value of a header from the request
---@param headers table The headers to check
---@param header string The header name to check
---@param dont_ignore_case boolean|nil If true, the header name will be case sensitive
---@return string|nil
M.get_header_value = function(headers, header, dont_ignore_case)
  header = dont_ignore_case and header or header:lower()
  for k, v in pairs(headers) do
    if k == header then
      return v
    end
  end
  return nil
end

---Get the name of a header from the request
---@param headers table The headers to check
---@param header string The header name to check
---@param dont_ignore_case boolean|nil If true, the header name will be case sensitive
---@return string|nil
M.get_header_name = function(headers, header, dont_ignore_case)
  header = dont_ignore_case and header or header:lower()
  for k, _ in pairs(headers) do
    if k:lower() == header then
      return k
    end
  end
  return nil
end

---Get a header from the request
---@param headers table The headers to check
---@param header string The header name to check
---@param value string|nil The value to check for or nil if only the header name should be checked
---@param dont_ignore_case boolean|nil If true, the header name will be case sensitive
---@return (string|nil), (string|nil) The header name and value or nil if not found
M.get_header = function(headers, header, value, dont_ignore_case)
  header = dont_ignore_case and header or header:lower()
  value = value and (dont_ignore_case and value or value:lower()) or nil
  if dont_ignore_case then
    if value == nil then
      for k, _ in pairs(headers) do
        if k == header then
          return k, headers[k]
        end
      end
    else
      for k, v in pairs(headers) do
        if k == header and v == value then
          return k, v
        end
      end
    end
  else
    if value == nil then
      for k, _ in pairs(headers) do
        if k:lower() == header then
          return k, headers[k]
        end
      end
    else
      for k, v in pairs(headers) do
        if k:lower() == header and v:lower() == value then
          return k, v
        end
      end
    end
  end
  return nil, nil
end

return M
