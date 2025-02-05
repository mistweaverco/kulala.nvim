---@diagnostic disable: duplicate-set-field
local api = vim.api

local UITestHelper = {}
local h = UITestHelper

local function true_if_nil(arg)
  return (arg or arg == nil) and true or arg
end

local function extend_table(tbl)
  local mt = {}
  mt = {
    to_string = h.to_string,
  }
  mt.__index = mt
  return setmetatable(tbl, mt)
end

--Remove tabs and spaces as tabs
string.clean = function(str) --luacheck: ignore
  str = vim.trim(str:gsub("\t", "")):gsub("^%s+", ""):gsub("%s+$", "")
  return tostring(str)
end

string.to_string = function(self, clean)
  return h.to_string(self, clean)
end

string.to_table = function(self, clean)
  return h.to_table(tostring(self), clean)
end

string.to_object = function(self)
  return loadstring("return " .. self:gsub("[\n\r]*", ""))()
end

---@param tbl string[]|string
h.to_string = function(tbl, clean)
  tbl = tbl or {}
  tbl = type(tbl) == "table" and tbl or { tbl }

  tbl = clean and h.to_table(table.concat(tbl, "\n"), true) or tbl

  return table.concat(tbl, "\n")
end

h.to_table = function(str, clean)
  str = type(str) == "table" and h.to_string(str, clean) or str

  return vim
    .iter(vim.split(str or "", "\n", { trimempty = clean }))
    :map(function(line)
      return clean and line:clean() or line
    end)
    :totable()
end

h.send_keys = function(keys)
  local cmd = "'normal " .. keys .. "'"
  vim.cmd.exe(cmd)
end

UITestHelper.expand_path = function(path)
  if vim.fn.filereadable(path) == 0 then
    local spec_path

    for i = 1, 5 do
      spec_path = debug.getinfo(i).short_src
      if spec_path and spec_path:find("_spec%.lua") then
        break
      end
    end

    spec_path = vim.fn.fnamemodify(spec_path, ":h")
    path = vim.uv.cwd() .. "/" .. spec_path .. "/" .. path
  end

  return path
end

---@param fixture_path string
---@return table|string
UITestHelper.load_fixture = function(fixture_path)
  local contents = vim.fn.readfile(h.expand_path(fixture_path))
  return h.to_string(contents, false)
end

UITestHelper.delete_all_bufs = function()
  -- Get a list of all buffer numbers
  local buffers = vim.api.nvim_list_bufs()

  -- Iterate over each buffer and delete it
  for _, buf in ipairs(buffers) do
    -- Check if the buffer is valid and loaded
    if vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end

---@param lines? string[]
---@param bufname? string
---@return integer bufnr
UITestHelper.create_buf = function(lines, bufname, scratch)
  lines = lines or {}
  scratch = true_if_nil(scratch)

  local bufnr = vim.api.nvim_create_buf(true, scratch)

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  api.nvim_set_current_buf(bufnr)
  api.nvim_win_set_cursor(0, { 1, 1 })

  if bufname then
    vim.api.nvim_buf_set_name(bufnr, bufname)
  end

  return bufnr
end

---@param bufnr integer
---@return string[] lines
UITestHelper.get_buf_lines = function(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return extend_table(lines)
end

---@param bufnr integer
---@param lines string[]
UITestHelper.set_buf_lines = function(bufnr, lines)
  return vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, h.to_table(lines))
end

---@return integer[] bufnr list
UITestHelper.list_loaded_bufs = function()
  local bufnr_list = vim.api.nvim_list_bufs()

  local loaded_bufs = {}
  for _, bufnr in ipairs(bufnr_list) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      loaded_bufs[#loaded_bufs + 1] = bufnr
    end
  end

  return loaded_bufs
end

---@return table [id:name]
UITestHelper.list_loaded_buf_names = function()
  return vim.iter(vim.api.nvim_list_bufs()):fold({}, function(acc, id)
    acc[tostring(id)] = vim.fn.bufname(id)
    return acc
  end)
end

return UITestHelper
