local M = {}

-- find nearest file in parent directories, starting from the current buffer file path
-- @param filename: string
-- @return string|nil
-- @usage local p = fs.find_file_in_parent_dirs('Makefile')
M.find_file_in_parent_dirs = function(filename)
  local dir = vim.fn.expand('%:p:h')
  while dir ~= '/' do
    local parent = dir .. '/' .. filename
    if vim.fn.filereadable(parent) == 1 then
      return parent
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  return nil
end

return M
