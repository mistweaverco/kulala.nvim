local DB = require("kulala.db")

local M = {}

---Get the current line number of the cursor, 1-indexed
M.get_current_line_number = function()
  local win_id = vim.fn.win_findbuf(DB.get_current_buffer())[1]
  return win_id and vim.api.nvim_win_get_cursor(win_id)[1] or 1
end

---Strips invalid characters at the beginning of the line, e.g. comment characters
M.strip_invalid_chars = function(tbl)
  local valid_1 = { "# @", "###", "------" }
  local valid_2 = [["%[%]<>{%%}@?%w%d]]

  return vim
    .iter(tbl)
    :map(function(line)
      local has_valid, s

      vim.iter(valid_1):each(function(pattern)
        s = line:find(pattern, 1, true)
        line = s and line:sub(s) or line
        has_valid = s or has_valid
      end)

      line = has_valid and line or line:gsub("^%s*([^" .. valid_2 .. "]*)(.*)$", "%2")

      return line
    end)
    :totable()
end

---Get the value of a meta tag from the request
---@param request table The request to check
---@param tag string The meta tag to check for
---@return string|nil
M.get_meta_tag = function(request, tag)
  tag = tag:lower()
  for _, meta in ipairs(request.metadata) do
    if meta.name:lower() == tag then return meta.value end
  end
  return nil
end

---Check if a request has a specific meta tag
---@param request table The request to check
---@param tag string The meta tag to check for
M.contains_meta_tag = function(request, tag)
  tag = tag:lower()
  for _, meta in ipairs(request.metadata) do
    if meta.name:lower() == tag then return true end
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

  if not value then
    for k, _ in pairs(headers) do
      if k:lower():find(header, 1, true) then return true end
    end
  else
    for k, v in pairs(headers) do
      if k:lower():find(header, 1, true) and v:lower():find(value, 1, true) then return true end
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
    if k:lower() == header then return v end
  end
end

---Get the name of a header from the request
---@param headers table The headers to check
---@param header string The header name to check
---@param dont_ignore_case boolean|nil If true, the header name will be case sensitive
---@return string|nil
M.get_header_name = function(headers, header, dont_ignore_case)
  header = dont_ignore_case and header or header:lower()
  for k, _ in pairs(headers) do
    if k:lower() == header then return k end
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
        if k == header then return k, headers[k] end
      end
    else
      for k, v in pairs(headers) do
        if k == header and v == value then return k, v end
      end
    end
  else
    if value == nil then
      for k, _ in pairs(headers) do
        if k:lower() == header then return k, headers[k] end
      end
    else
      for k, v in pairs(headers) do
        if k:lower() == header and v:lower() == value then return k, v end
      end
    end
  end
  return nil, nil
end

return M
