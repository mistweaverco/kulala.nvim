local Logger = require("kulala.logger")

local M = {}

M.get_current_buffer = function()
  return require("kulala.db").get_current_buffer()
end

---Get the OS
---@return "windows" | "mac" | "unix" | "unknown"
M.get_os = function()
  if vim.fn.has("unix") == 1 then return "unix" end
  if vim.fn.has("mac") == 1 then return "mac" end
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") then return "windows" end

  return "unknown"
end

---The OS
---@type "windows" | "mac" | "unix" | "unknown"
M.os = M.get_os()

---Get the path separator for the current OS
---@return "\\" | "/"
M.get_path_separator = function()
  if M.os == "windows" then return "\\" end
  return "/"
end

---Path separator
---@type "\\" | "/"
M.ps = M.get_path_separator()

---Join paths -- similar to os.path.join in python
---@vararg string
---@return string
M.join_paths = function(...)
  if M.os == "windows" then
    for _, v in ipairs({ ... }) do
      -- if the path contains at least one forward slash,
      -- then it needs to be converted to backslashes
      if v:match("/") then
        local parts = {}
        for _, p in ipairs({ ... }) do
          p = p:gsub("/", "\\")
          table.insert(parts, p)
        end
        return table.concat(parts, M.ps)
      end
    end

    return table.concat({ ... }, M.ps)
  end

  return table.concat({ ... }, M.ps)
end

---Returns true if the path is absolute, false otherwise
M.is_absolute_path = function(path)
  if path:match("^/") or path:match("^%a:\\") then return true end
  return false
end

---Either returns the absolute path if the path is already absolute or
---joins the path with the current buffer directory
---@param path string
---@param root string|nil -- root directory
M.get_file_path = function(path, root)
  local ex_path = vim.fn.expand(path, true)
  path = ex_path ~= "" and ex_path or path
  root = root and vim.fn.fnamemodify(root, ":h")

  if M.is_absolute_path(path) then return path end
  if path:sub(1, 2) == "./" or path:sub(1, 2) == ".\\" then path = path:sub(3) end

  return M.join_paths(root or M.get_current_buffer_dir(), path)
end

-- This is mainly used for determining if the current buffer is a non-http file
-- and therefore maybe we need to parse a fenced code block
M.is_non_http_file = function()
  local buf = M.get_current_buffer()

  local extensions = { "http", "rest" }
  local ft = vim.bo[buf].filetype
  local ext = vim.fn.fnamemodify(M.get_current_buffer_path(), ":e")

  return vim.iter(extensions):all(function(e)
    return ext ~= e and ft ~= e
  end)
end

-- find nearest file in parent directories, starting from the current buffer file path
--- @param filename string|function
--- @return string|nil
--- @usage local p = fs.find_file_in_parent_dirs('Makefile')
M.find_file_in_parent_dirs = function(filename)
  return vim.fs.find(filename, {
    upward = true,
    limit = 1,
    path = M.get_current_buffer_dir(),
  })[1]
end

M.copy_file = function(source, destination)
  return vim.loop.fs_copyfile(source, destination, 0)
end

---Get the current buffer directory or current working dir if path is not valid
---@return string
M.get_current_buffer_dir = function()
  -- Get the full path of the current buffer
  local buf_path = M.get_current_buffer_path()
  buf_path = vim.fn.filereadable(buf_path) ~= 0 and buf_path or vim.uv.cwd()

  -- Extract the directory part from the buffer path
  return vim.fn.fnamemodify(buf_path, ":p:h")
end

M.get_current_buffer_path = function()
  local buf = M.get_current_buffer()
  return buf and vim.api.nvim_buf_get_name(buf)
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
  end, { path = M.get_current_buffer_dir(), type = "file", limit = 1000 })
end

-- Writes string to file
--- @param filename string
--- @param content string
--- @param append boolean|nil
--- @usage fs.write_file('Makefile', 'all: \n\t@echo "Hello World"')
--- @usage fs.write_file('Makefile', 'all: \n\t@echo "Hello World"', true)
--- @return boolean
--- @usage local p = fs.write_file('Makefile', 'all: \n\t@echo "Hello World"')
M.write_file = function(filename, content, append)
  local f
  if append then
    f = io.open(filename, "a")
  else
    f = io.open(filename, "w")
  end

  if not f then return false end

  f:write(content)
  f:close()

  return true
end

-- Delete a file
--- @param filename string
--- @return boolean
--- @usage local p = fs.delete_file('Makefile')
M.delete_file = function(filename)
  return vim.fn.delete(filename) ~= 0
end

-- Check if a file exists
--- @param filename string
--- @return boolean
--- @usage local p = fs.file_exists('Makefile')
M.file_exists = function(filename)
  return vim.fn.filereadable(filename) == 1
end

M.copy_dir = function(source, destination)
  if M.os == "unix" or M.os == "mac" then
    vim.system({ "cp", "-r", source .. M.ps .. ".", destination }):wait()
  elseif M.os == "windows" then
    vim.system({ "xcopy", "/H", "/E", "/I", source .. M.ps .. "*", destination }):wait()
  end
end

M.ensure_dir_exists = function(dir)
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end
end

-- Get plugin tmp directory
--- @return string
--- @usage local p = fs.get_plugin_tmp_dir()
M.get_plugin_tmp_dir = function()
  local cache = vim.fn.stdpath("cache")
  ---@cast cache string
  local dir = M.join_paths(cache, "kulala")

  M.ensure_dir_exists(dir)
  return dir
end

M.get_scripts_dir = function()
  local dir = M.join_paths(M.get_plugin_root_dir(), "parser", "scripts")
  return dir
end

M.get_tmp_scripts_build_dir = function()
  local dir = M.join_paths(M.get_plugin_tmp_dir(), "scripts", "build")
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

---Delete all files in a directory
---@param dir string
---@usage fs.delete_files_in_directory('tmp')
---@return string[] deleted_files
M.delete_files_in_directory = function(dir)
  local deleted_files = {}
  local scandir = vim.uv.fs_scandir(dir)

  if scandir then
    while true do
      local name, type = vim.loop.fs_scandir_next(scandir)

      if not name then break end

      -- Only delete files, not directories except .*
      if type == "file" and not name:match("^%.") then
        local filepath = M.join_paths(dir, name)
        local success, err = vim.uv.fs_unlink(filepath)

        if not success then
          print("Error deleting file:", filepath, err)
        else
          table.insert(deleted_files, filepath)
        end
      end
    end
  else
    print("Error opening directory:", dir)
  end

  return deleted_files
end

M.get_request_scripts_variables = function()
  local dir = M.get_request_scripts_dir()

  if M.file_exists(dir .. "/request_variables.json") then
    return vim.fn.json_decode(M.read_file(M.join_paths(dir, "request_variables.json")))
  end
end

M.get_global_scripts_variables_file_path = function()
  return M.join_paths(M.get_tmp_scripts_dir(), "global_variables.json")
end

M.get_global_scripts_variables = function()
  local fp = M.get_global_scripts_variables_file_path()
  if M.file_exists(fp) then return vim.fn.json_decode(M.read_file(fp)) end
end

-- Check if a command is available
--- @param cmd string
--- @return boolean
--- @usage local p = fs.command_exists('ls')
M.command_exists = function(cmd)
  return vim.fn.executable(cmd) == 1
end

M.command_path = function(cmd)
  return vim.fn.exepath(cmd)
end

M.get_plugin_root_dir = function()
  local source = debug.getinfo(1).source
  local dir_path = source:match("@(.*/)") or source:match("@(.*\\)")

  if not dir_path then return end

  return dir_path .. ".."
end

---Gets a directory path for the plugin
---@param paths string[]
---@return string
M.get_plugin_path = function(paths)
  return M.get_plugin_root_dir() .. M.ps .. table.concat(paths, M.ps)
end

---Read a file with path absolute or relative to buffer dir
---@param filename string path absolutre or relative to buffer dir
---@param is_binary boolean|nil
---@return string|nil
---@usage local p = fs.read_file('Makefile')
M.read_file = function(filename, is_binary)
  local read_mode = is_binary and "rb" or "r"

  filename = M.get_file_path(filename)
  local f = io.open(filename, read_mode)

  if not f then return end

  local content = f:read("*a")
  if not content then return end

  content = is_binary and content or content:gsub("\r\n", "\n")
  f:close()

  return content
end

M.read_json = function(filename)
  local content = M.read_file(filename)
  if not content then return end

  local status, result = pcall(vim.json.decode, content, { object = true, array = true })
  if not status then return Logger.error("Error decoding JSON file: " .. filename .. ": " .. result) end

  return result
end

M.write_json = function(filename, data)
  local content = vim.json.encode(data)
  if not content then return end

  content = content:gsub("\\/", "/"):gsub('\\"', '"')
  return M.write_file(filename, content)
end

---@param content string
---@param binary? boolean|nil
M.get_temp_file = function(content, binary)
  local tmp_file = vim.fn.tempname()
  local mode = binary and "wb" or "w"
  local f = io.open(tmp_file, mode)

  if not f then return end

  f:write(content)
  f:close()

  return tmp_file
end

M.get_binary_temp_file = function(content)
  return M.get_temp_file(content, true)
end

---Read file lines
---@param filename string
---@return string[]
M.read_file_lines = function(filename)
  local f = io.open(filename, "r")
  local lines = {}

  if not f then return {} end

  for line in f:lines() do
    table.insert(lines, line)
  end

  f:close()

  return lines
end

---Includes contents of path into the file
---@param file file* handle to file to append to
---@param path string path of file to include
M.include_file = function(file, path)
  local status = true
  local BUFSIZE = 2 ^ 13 -- 8K

  local file_to_include = io.open(path, "rb")
  if not file_to_include then return end

  while true do
    local chunk = file_to_include:read(BUFSIZE)
    if not chunk then break end
    ---@diagnostic disable-next-line: cast-local-type
    status = status and file:write(chunk)
  end

  return status and file_to_include:close()
end

--- Delete *.js request script files and request_variables.json
M.delete_request_scripts_files = function() -- cache/nvim/kulala/scripts/requests
  local dir = M.get_request_scripts_dir()
  M.delete_files_in_directory(dir)
end

---Deletes all cached files, request scripts and variables
---except global_variables.json in cache/nvim/kulala/scripts
M.delete_cached_files = function(silent) -- cache/nvim/kulala
  local tmp_dir = M.get_plugin_tmp_dir()
  local deleted_files = M.delete_files_in_directory(tmp_dir)

  --TODO: delete global_variables.json ?

  local list = vim.iter(deleted_files):fold("", function(list, file)
    return list .. "- " .. file .. "\n"
  end)

  if not silent then Logger.info("Deleted files:\n" .. list) end
end

return M
