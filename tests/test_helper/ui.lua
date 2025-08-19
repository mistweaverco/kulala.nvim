local Fs = require("kulala.utils.fs")
local Globals = require("kulala.globals")

---@diagnostic disable: duplicate-set-field

local h = {}

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

---@param indent? integer -- number of spaces to remove
string.deindent = function(self, indent)
  local tbl = vim.split(tostring(self), "\n")
  indent = indent or math.huge

  vim.iter(tbl):each(function(line)
    if not line:find("%w") then return end
    local spaces = line:match("^(%s+)") or ""
    indent = math.min(#spaces, indent)
  end)

  for i = 1, #tbl do
    tbl[i] = tbl[i]:sub(indent + 1)
  end

  return table.concat(tbl, "\n"):gsub("\n$", "")
end

---@param self string
string.to_string = function(self, clean)
  return h.to_string(self, clean)
end

---@param self string
---@param clean boolean|nil -- remove tabs and trim spaces
---@return string[]
string.to_table = function(self, clean)
  return h.to_table(tostring(self), clean)
end

---@param self string
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

---@param buf? number|nil -- get global maps if nil
---@param mode? string -- default 'n'
---@param replace_leader? boolean|nil -- replaces leader symbol with <leader>
h.get_maps = function(buf, mode, replace_leader)
  replace_leader = replace_leader ~= false
  mode = mode or "n"

  local maps = {}
  local list = buf and vim.api.nvim_buf_get_keymap(buf, mode) or vim.api.nvim_get_keymap(mode)

  vim.tbl_map(function(map)
    map.lhs = replace_leader and map.lhs:gsub(vim.g.mapleader, "<leader>") or map.lhs
    maps[map.lhs] = map.desc
  end, list)

  return maps
end

h.delete_all_maps = function()
  vim.iter({ "n", "v" }):each(function(mode)
    vim.iter(h.get_maps(nil, mode)):each(function(lhs, _)
      vim.keymap.del(mode, lhs)
    end)
  end)
end

h.has_string = function(str, pattern)
  return str:find(pattern, 1, true) and true
end

h.expand_path = function(path)
  if vim.fn.filereadable(path) == 1 then return path end

  local spec_path

  for i = 1, 5 do
    spec_path = debug.getinfo(i).short_src
    if spec_path and spec_path:find("_spec%.lua") then break end
  end

  spec_path = vim.fn.fnamemodify(spec_path, ":h")
  path = vim.fs.joinpath(vim.uv.cwd(), spec_path, path)

  return Fs.normalize_path(path)
end

---@param fixture_path string
---@return table|string
h.load_fixture = function(fixture_path, binary)
  local contents = vim.fn.readfile(h.expand_path(fixture_path), binary and "B")
  return h.to_string(contents, false)
end

h.delete_all_bufs = function()
  -- Get a list of all buffer numbers
  local buffers = vim.api.nvim_list_bufs()

  -- Iterate over each buffer and delete it
  for _, buf in ipairs(buffers) do
    -- Check if the buffer is valid and loaded
    if vim.api.nvim_buf_is_loaded(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end
end

---@param lines? string[]
---@param bufname? string
---@return integer bufnr
h.create_buf = function(lines, bufname, scratch)
  lines = lines or {}
  scratch = scratch ~= false

  local bufnr = vim.api.nvim_create_buf(true, scratch)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_win_set_cursor(0, { 1, 1 })

  if bufname then vim.api.nvim_buf_set_name(bufnr, bufname) end

  return bufnr
end

h.get_kulala_buf = function()
  return vim.fn.bufnr(Globals.UI_ID)
end

h.get_kulala_win = function()
  return vim.fn.bufwinid(Globals.UI_ID)
end

h.get_extmarks = function(buf, line_start, line_end, opts)
  opts = vim.tbl_extend("keep", opts or {}, { details = true })
  return vim.api.nvim_buf_get_extmarks(buf, -1, { line_start or 0, 0 }, { line_end or -1, -1 }, opts)
end

h.has_highlight = function(buf, line, hl)
  local marks = h.get_extmarks(buf, line, line, { type = "highlight" })
  return vim.iter(marks):any(function(mark)
    return mark[4].hl_group == hl
  end)
end

---@param bufnr integer
---@return string[] lines
h.get_buf_lines = function(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return extend_table(lines)
end

---@param bufnr integer
---@param lines string[]
h.set_buf_lines = function(bufnr, lines, line_s, line_e)
  return vim.api.nvim_buf_set_lines(bufnr, line_s or 0, line_e or -1, false, h.to_table(lines))
end

---@return integer[] bufnr list
h.list_loaded_bufs = function()
  local bufnr_list = vim.api.nvim_list_bufs()

  local loaded_bufs = {}
  for _, bufnr in ipairs(bufnr_list) do
    if vim.api.nvim_buf_is_loaded(bufnr) then loaded_bufs[tostring(bufnr)] = vim.fn.bufname(bufnr) end
  end

  return loaded_bufs
end

---@return table [id:name]
h.list_loaded_buf_names = function()
  return vim.iter(vim.api.nvim_list_bufs()):fold({}, function(acc, id)
    local name = vim.fn.bufname(id)
    local current_buf = vim.api.nvim_get_current_buf()

    if id == current_buf then name = "*" .. name end

    acc[tostring(id)] = name
    return acc
  end)
end

return h
