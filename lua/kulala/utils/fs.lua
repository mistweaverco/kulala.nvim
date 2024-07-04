local M = {}

-- find nearest file in parent directories, starting from the current buffer file path
-- @param filename: string
-- @return string|nil
-- @usage local p = fs.find_file_in_parent_dirs('Makefile')
M.find_file_in_parent_dirs = function(filename)
  local dir = vim.fn.expand('%:p:h')
  while dir ~= '/' and dir ~= '' do
    local parent = dir .. '/' .. filename
    if vim.fn.filereadable(parent) == 1 then
      return parent
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  return nil
end

-- Writes string to file
-- @param filename: string
-- @param content: string
-- @usage fs.write_file('Makefile', 'all: \n\t@echo "Hello World"')
-- @return boolean
-- @usage local p = fs.write_file('Makefile', 'all: \n\t@echo "Hello World"')
M.write_file = function(filename, content)
  local f = io.open(filename, 'w')
  if f == nil then
    return false
  end
  f:write(content)
  f:close()
  return true
end

-- Check if a file exists
-- @param filename: string
-- @return boolean
-- @usage local p = fs.file_exists('Makefile')
M.file_exists = function(filename)
  return vim.fn.filereadable(filename) == 1
end

-- Get plugin tmp directory
-- @return string
-- @usage local p = fs.get_plugin_tmp_dir()
M.get_plugin_tmp_dir = function()
  local dir = vim.fn.stdpath('data') .. '/tmp/kulala'
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end
  return dir
end

-- Check if a command is available
-- @param cmd: string
-- @return boolean
-- @usage local p = fs.command_exists('ls')
M.command_exists = function(cmd)
  return vim.fn.executable(cmd) == 1
end

-- Read a file
-- @param filename: string
-- @return string
-- @usage local p = fs.read_file('Makefile')
M.read_file = function(filename)
  local f = io.open(filename, 'r')
  if f == nil then
    return nil
  end
  local content = f:read('*a')
  f:close()
  return content
end

return M
