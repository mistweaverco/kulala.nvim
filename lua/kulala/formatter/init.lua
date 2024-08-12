local M = {}

M.format = function(formatter, contents)
  if type(formatter) == "function" then
    return formatter(base_table[method].body)
  elseif type(formatter) == "table" then
    local cmd = formatter
    return vim.system(cmd, { stdin = contents, text = true }):wait().stdout
  end
  return contents
end

return M
