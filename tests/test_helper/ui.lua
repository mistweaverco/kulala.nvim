local api = vim.api

local UITestHelper = {}
local h = UITestHelper

--Remove tabs and spaces as tabs
---@diagnostic disable-next-line: duplicate-set-field
string.clean = function(str) --luacheck: ignore
  str = vim.trim(str:gsub("\t", "")):gsub("^%s+", ""):gsub("%s+$", "")
  return tostring(str)
end

local function default_true(arg)
  if arg == false then
    return false
  else
    return true
  end
end

---@param tbl string[]|string
h.to_string = function(tbl, clean)
  tbl = tbl or {}
  tbl = type(tbl) == "table" and tbl or { tbl }

  clean = default_true(clean)
  tbl = clean and h.to_table(table.concat(tbl, "\n")) or tbl

  return table.concat(tbl, "\n")
end

h.to_table = function(str, clean)
  clean = default_true(clean)
  str = type(str) == "table" and h.to_string(str, clean) or str

  return vim
    .iter(vim.split(str or "", "\n", { trimempty = clean }))
    :map(function(line)
      return clean and tostring(line:clean()) or line
    end)
    :totable()
end

h.load_fixture = function(fixture_name)
  local fixtures_path = vim.uv.cwd() .. "/tests/ui/fixtures/"
  return h.to_string(vim.fn.readfile(fixtures_path .. fixture_name), false)
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
  scratch = default_true(scratch)

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
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

---@param bufnr integer
---@param lines string[]
UITestHelper.set_buf_lines = function(bufnr, lines)
  return vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, h.to_table(lines))
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

return UITestHelper
