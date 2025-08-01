local Config = require("kulala.config")

local M = {}

M.trim = function(str)
  return str:gsub("^%s+", ""):gsub("%s+$", "")
end

M.remove_extra_space = function(str)
  return M.trim(str):gsub("%s+", " ")
end

M.remove_newline = function(str)
  return str:gsub("[\n\r]", "")
end

M.url_encode = function(str, skip)
  local pattern = "([^%w%.%-_~" .. (skip or "") .. "])"
  if not str then return end

  return str:gsub("\n", "\r\n"):gsub(pattern, function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

M.url_encode_skipencoded = function(str, skip)
  local res = ""
  repeat
    local startpos, endpos = str:find("%%%x%x")
    if startpos and endpos then
      res = res .. M.url_encode(str:sub(1, startpos - 1), skip) .. str:sub(startpos, endpos)
      str = str:sub(endpos + 1)
    else
      res = res .. M.url_encode(str, skip)
      str = ""
    end
  until str == ""
  return res
end

M.url_decode = function(str)
  if not str then return str end

  return str
    :gsub("%%(%x%x)", function(h)
      return string.char(tonumber(h, 16))
    end)
    :gsub("+", " ")
end

M.cut = function(str, delimiter)
  local pos = str:find(delimiter)
  if not pos then return str, "" end

  return str:sub(1, pos - 1), str:sub(pos + 1)
end

return M
