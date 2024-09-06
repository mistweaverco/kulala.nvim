local M = {}

--- Path separator
M.ps = package.config:sub(1, 1)

---Join paths -- similar to os.path.join in python
---@vararg string
---@return string
M.join_paths = function(...)
  return table.concat({ ... }, M.ps)
end

-- This is mainly used for determining if the current buffer is a non-http file
-- and therefore maybe we need to parse a fenced code block
M.is_non_http_file = function()
  local ft = vim.bo.filetype
  local ext = vim.fn.expand("%:e")
  return ext ~= "http" and ext ~= "rest" and ft ~= "http" and ft ~= "rest"
end

-- find nearest file in parent directories, starting from the current buffer file path
--- @param filename string
--- @return string|nil
--- @usage local p = fs.find_file_in_parent_dirs('Makefile')
M.find_file_in_parent_dirs = function(filename)
  return vim.fs.find(filename, {
    upward = true,
    limit = 1,
    path = vim.fn.expand("%:p:h"),
  })[1]
end

M.copy_file = function(source, destination)
  return vim.loop.fs_copyfile(source, destination, 0)
end

---Get the current buffer directory
---@return string
M.get_current_buffer_dir = function()
  -- Get the full path of the current buffer
  local buffer_path = vim.api.nvim_buf_get_name(0)
  -- Extract the directory part from the buffer path
  local buffer_dir = vim.fn.fnamemodify(buffer_path, ":h")
  return buffer_dir
end

---Get UUID
---@return string
---@usage local p = fs.get_uuid()
M.get_uuid = function()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  local res = string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
  return res
end

---Get the directory of a file path
---@param filepath string
---@return string
M.get_dir_by_filepath = function(filepath)
  return vim.fn.fnamemodify(filepath, ":h")
end

M.find_all_http_files = function()
  return vim.fs.find(function(name)
    return name:match("%.http$") or name:match("%.rest$")
  end, { path = vim.fn.getcwd(), type = "file", limit = 1000 })
end

-- Writes string to file
--- @param filename string
--- @param content string
--- @param append boolean
--- @usage fs.write_file('Makefile', 'all: \n\t@echo "Hello World"')
--- @usage fs.write_file('Makefile', 'all: \n\t@echo "Hello World"', true)
--- @return boolean
--- @usage local p = fs.write_file('Makefile', 'all: \n\t@echo "Hello World"')
M.write_file = function(filename, content, append)
  local f = nil
  if append then
    f = io.open(filename, "a")
  else
    f = io.open(filename, "w")
  end

  if f == nil then
    return false
  end

  f:write(content)
  f:close()
  return true
end

-- Delete a file
--- @param filename string
--- @return boolean
--- @usage local p = fs.delete_file('Makefile')
M.delete_file = function(filename)
  if vim.fn.delete(filename) == 0 then
    return false
  end
  return true
end

-- Check if a file exists
--- @param filename string
--- @return boolean
--- @usage local p = fs.file_exists('Makefile')
M.file_exists = function(filename)
  return vim.fn.filereadable(filename) == 1
end

M.ensure_dir_exists = function(dir)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

-- Get plugin tmp directory
--- @return string
--- @usage local p = fs.get_plugin_tmp_dir()
M.get_plugin_tmp_dir = function()
  local dir = M.join_paths(vim.fn.stdpath("data"), "tmp", "kulala")
  M.ensure_dir_exists(dir)
  return dir
end

M.get_scripts_dir = function()
  local dir = M.join_paths(M.get_plugin_root_dir(), "scripts")
  return dir
end

M.get_tmp_scripts_dir = function()
  local dir = M.join_paths(M.get_plugin_tmp_dir(), "scripts")
  M.ensure_dir_exists(dir)
  return dir
end

M.get_request_scripts_dir = function()
  local dir = M.join_paths(M.get_plugin_tmp_dir(), "scripts", "requests")
  M.ensure_dir_exists(dir)
  return dir
end

M.delete_files_in_directory = function(dir)
  -- Open the directory for scanning
  local scandir = vim.loop.fs_scandir(dir)
  if scandir then
    -- Iterate over each file in the directory
    while true do
      local name, type = vim.loop.fs_scandir_next(scandir)
      if not name then
        break
      end
      -- Only delete files, not directories
      if type == "file" then
        local filepath = dir .. M.ps .. name
        local success, err = vim.loop.fs_unlink(filepath)
        if not success then
          print("Error deleting file:", filepath, err)
        end
      end
    end
  else
    print("Error opening directory:", dir)
  end
end

M.delete_request_scripts_files = function()
  local dir = M.get_request_scripts_dir()
  M.delete_files_in_directory(dir)
end

M.get_request_scripts_variables = function()
  local dir = M.get_request_scripts_dir()
  if M.file_exists(dir .. "/request_variables.json") then
    return vim.fn.json_decode(M.read_file(M.join_paths(dir, "request_variables.json")))
  end
  return nil
end

M.get_global_scripts_variables_file_path = function()
  return M.join_paths(M.get_tmp_scripts_dir(), "global_variables.json")
end

M.get_global_scripts_variables = function()
  local fp = M.get_global_scripts_variables_file_path()
  if M.file_exists(fp) then
    return vim.fn.json_decode(M.read_file(fp))
  end
  return nil
end

-- Check if a command is available
--- @param cmd string
--- @return boolean
--- @usage local p = fs.command_exists('ls')
M.command_exists = function(cmd)
  return vim.fn.executable(cmd) == 1
end

M.get_plugin_root_dir = function()
  local source = debug.getinfo(1).source
  local dir_path = source:match("@(.*/)") or source:match("@(.*\\)")
  if dir_path == nil then
    return nil
  end
  return dir_path .. ".."
end

---Gets a directory path for the plugin
---@param paths string[]
---@return string
M.get_plugin_path = function(paths)
  return M.get_plugin_root_dir() .. M.ps .. table.concat(paths, M.ps)
end

-- Read a file
--- @param filename string
--- @return string|nil
--- @usage local p = fs.read_file('Makefile')
M.read_file = function(filename)
  local f = io.open(filename, "r")
  if f == nil then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

---Read file lines
---@param filename string
---@return string[]
M.read_file_lines = function(filename)
  local f = io.open(filename, "r")
  if f == nil then
    return {}
  end
  local lines = {}
  for line in f:lines() do
    table.insert(lines, line)
  end
  f:close()
  return lines
end

return M
