local M = {}

M.trim = function(str)
  str = string.gsub(str, "^%s+", "")
  str = string.gsub(str, "%s+$", "")
  return str
end

M.remove_extra_space = function(str)
  str = string.gsub(str, "%s+", " ")
  str = string.gsub(str, "^%s+", "")
  str = string.gsub(str, "%s+$", "")
  return str
end

M.remove_newline = function(str)
  str = string.gsub(str, "\n", "")
  str = string.gsub(str, "\r", "")
  return str
end

M.url_encode = function(str)
  if str then
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w._~-])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
  end
  return str
end

M.url_decode = function(str)
  if str then
    str = string.gsub(str, "%%(%x%x)", function(h)
      return string.char(tonumber(h, 16))
    end)
    str = string.gsub(str, "+", " ")
  end
  return str
end

return M
