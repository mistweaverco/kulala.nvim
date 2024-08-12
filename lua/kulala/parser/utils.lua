local M = {}

M.contains_meta_tag = function(request, tag)
  for _, meta in ipairs(request.metadata) do
    if meta.name == tag then
      return true
    end
  end
  return false
end

M.contains_header = function(headers, header, value)
  for k, v in pairs(headers) do
    if k == header and v == value then
      return true
    end
  end
  return false
end

return M
