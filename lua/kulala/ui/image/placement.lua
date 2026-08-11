local Image = require("kulala.ui.image.image")
local terminal = require("kulala.ui.image.terminal")
local util = require("kulala.ui.image.util")

---@class kulala.image.Placement
---@field img kulala.Image
---@field id number
---@field buf number
---@field opts { pos?: {[1]:number,[2]:number}, auto_resize?: boolean, max_width?: number, max_height?: number }
---@field augroup number
---@field closed? boolean
---@field eids number[]
local M = {}
M.__index = M

local ns = vim.api.nvim_create_namespace("kulala.image")
M.ns = ns
local PLACEHOLDER = vim.fn.nr2char(0x10EEEE)
local placements = {} ---@type table<number, table<number, kulala.image.Placement>>

-- stylua: ignore
-- luacheck: ignore 631
local diacritics = vim.split( "0305,030D,030E,0310,0312,033D,033E,033F,0346,034A,034B,034C,0350,0351,0352,0357,035B,0363,0364,0365,0366,0367,0368,0369,036A,036B,036C,036D,036E,036F,0483,0484,0485,0486,0487,0592,0593,0594,0595,0597,0598,0599,059C,059D,059E,059F,05A0,05A1,05A8,05A9,05AB,05AC,05AF,05C4,0610,0611,0612,0613,0614,0615,0616,0617,0657,0658,0659,065A,065B,065D,065E,06D6,06D7,06D8,06D9,06DA,06DB,06DC,06DF,06E0,06E1,06E2,06E4,06E7,06E8,06EB,06EC,0730,0732,0733,0735,0736,073A,073D,073F,0740,0741,0743,0745,0747,0749,074A,07EB,07EC,07ED,07EE,07EF,07F0,07F1,07F3,0816,0817,0818,0819,081B,081C,081D,081E,081F,0820,0821,0822,0823,0825,0826,0827,0829,082A,082B,082C,082D,0951,0953,0954,0F82,0F83,0F86,0F87,135D,135E,135F,17DD,193A,1A17,1A75,1A76,1A77,1A78,1A79,1A7A,1A7B,1A7C,1B6B,1B6D,1B6E,1B6F,1B70,1B71,1B72,1B73,1CD0,1CD1,1CD2,1CDA,1CDB,1CE0,1DC0,1DC1,1DC3,1DC4,1DC5,1DC6,1DC7,1DC8,1DC9,1DCB,1DCC,1DD1,1DD2,1DD3,1DD4,1DD5,1DD6,1DD7,1DD8,1DD9,1DDA,1DDB,1DDC,1DDD,1DDE,1DDF,1DE0,1DE1,1DE2,1DE3,1DE4,1DE5,1DE6,1DFE,20D0,20D1,20D4,20D5,20D6,20D7,20DB,20DC,20E1,20E7,20E9,20F0,2CEF,2CF0,2CF1,2DE0,2DE1,2DE2,2DE3,2DE4,2DE5,2DE6,2DE7,2DE8,2DE9,2DEA,2DEB,2DEC,2DED,2DEE,2DEF,2DF0,2DF1,2DF2,2DF3,2DF4,2DF5,2DF6,2DF7,2DF8,2DF9,2DFA,2DFB,2DFC,2DFD,2DFE,2DFF,A66F,A67C,A67D,A6F0,A6F1,A8E0,A8E1,A8E2,A8E3,A8E4,A8E5,A8E6,A8E7,A8E8,A8E9,A8EA,A8EB,A8EC,A8ED,A8EE,A8EF,A8F0,A8F1,AAB0,AAB2,AAB3,AAB7,AAB8,AABE,AABF,AAC1,FE20,FE21,FE22,FE23,FE24,FE25,FE26,10A0F,10A38,1D185,1D186,1D187,1D188,1D189,1D1AA,1D1AB,1D1AC,1D1AD,1D242,1D243,1D244", ",")
local positions = setmetatable({}, {
  __index = function(t, k)
    t[k] = vim.fn.nr2char(tonumber(diacritics[k], 16))
    return t[k]
  end,
})

---@param buf? number
function M.clean(buf)
  for _, b in ipairs(buf and { buf } or vim.tbl_keys(placements)) do
    for _, p in pairs(placements[b] or {}) do
      p:close()
    end
  end
end

---@param buf number
---@param src string
---@param opts? table
---@return kulala.image.Placement
function M.new(buf, src, opts)
  local self = setmetatable({}, M)
  self.opts = opts or {}
  self.opts.pos = self.opts.pos or { 1, 0 }
  self.buf = buf
  self.eids = {}

  self.img = Image.new(src)
  self.img:place(self)

  self.augroup = vim.api.nvim_create_augroup("kulala.image." .. tostring(self.id), { clear = true })

  if self.opts.auto_resize then
    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "WinResized", "VimResized" }, {
      group = self.augroup,
      callback = function()
        vim.schedule(function()
          self:update()
        end)
      end,
    })
  end

  placements[self.buf] = placements[self.buf] or {}
  placements[self.buf][self.id] = self

  vim.schedule(function()
    self:update()
  end)
  return self
end

function M:wins()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_buf(win) == self.buf
  end, vim.api.nvim_tabpage_list_wins(0))
end

function M:close()
  if self.closed then return end
  if placements[self.buf] then placements[self.buf][self.id] = nil end
  self.closed = true
  self.img:del(self.id)
  if vim.api.nvim_buf_is_valid(self.buf) then
    for _, eid in ipairs(self.eids) do
      pcall(vim.api.nvim_buf_del_extmark, self.buf, ns, eid)
    end
  end
  pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
end

---@param loc { [1]: number, [2]: number, width: number, height: number }
function M:render_grid(loc)
  local hl = "KulalaImage" .. self.id
  pcall(vim.api.nvim_set_hl, 0, hl, {
    fg = self.img.id,
    sp = self.id,
    bg = "NONE",
    nocombine = true,
  })

  local height = math.min(#diacritics, loc.height)
  local width = math.min(#diacritics, loc.width)
  local lines = {}
  for r = 1, height do
    local line = {}
    for c = 1, width do
      line[#line + 1] = PLACEHOLDER
      line[#line + 1] = positions[r]
      line[#line + 1] = positions[c]
    end
    lines[#lines + 1] = table.concat(line)
  end

  for _, eid in ipairs(self.eids) do
    pcall(vim.api.nvim_buf_del_extmark, self.buf, ns, eid)
  end
  self.eids = {}

  local row = math.max(0, (self.opts.pos[1] or 1) - 1)
  local col = self.opts.pos[2] or 0
  if #lines == 0 then return end

  local first = table.remove(lines, 1)
  self.eids[#self.eids + 1] = vim.api.nvim_buf_set_extmark(self.buf, ns, row, col, {
    virt_text = { { first, hl } },
    virt_text_pos = "overlay",
    virt_lines = vim.tbl_map(function(l)
      return { { l, hl } }
    end, lines),
  })
end

function M:render_fallback(state)
  vim.api.nvim_buf_clear_namespace(self.buf, ns, 0, -1)
  -- Drop any previous placement so WezTerm does not stack images at stale coords.
  terminal.request { a = "d", d = "i", i = self.img.id, p = self.id }

  local buf_lnum = math.max(1, state.loc[1] or self.opts.pos[1] or 1)
  local buf_col = math.max(1, (state.loc[2] or self.opts.pos[2] or 0) + 1)

  for _, win in ipairs(state.wins) do
    -- Keep the anchor line on-screen so screenpos maps into this window.
    vim.api.nvim_win_call(win, function()
      local topline = vim.fn.line("w0")
      local botline = vim.fn.line("w$")
      if buf_lnum < topline or buf_lnum > botline then
        vim.fn.winrestview { topline = buf_lnum, lnum = buf_lnum, col = 0, leftcol = 0 }
      end
    end)

    local sp = vim.fn.screenpos(win, buf_lnum, buf_col)
    if type(sp) ~= "table" or (sp.row or 0) <= 0 or (sp.col or 0) <= 0 then
      -- Fallback: window top-left content cell (accounts for winbar via getwininfo).
      local info = vim.fn.getwininfo(win)[1]
      if info then
        local row = info.winrow
        if vim.wo[win].winbar ~= "" then row = row + 1 end
        sp = { row = row, col = info.wincol + (info.textoff or 0) }
      end
    end

    if type(sp) == "table" and (sp.row or 0) > 0 and (sp.col or 0) > 0 then
      -- set_cursor expects 1-based row and 0-based col (it adds 1 to col).
      terminal.set_cursor { sp.row, sp.col - 1 }
      terminal.request {
        a = "p",
        i = self.img.id,
        p = self.id,
        C = 1,
        c = state.loc.width,
        r = state.loc.height,
      }
    end
  end
end

function M:state()
  local width, height = vim.o.columns, vim.o.lines
  local wins = self:wins()

  for _, win in ipairs(wins) do
    local info = vim.fn.getwininfo(win)[1]
    if info then
      width = math.min(width, math.max(1, info.width - (info.textoff or 0)))
      height = math.min(height, info.height)
    else
      width = math.min(width, vim.api.nvim_win_get_width(win))
      height = math.min(height, vim.api.nvim_win_get_height(win))
    end
  end
  if self.opts.max_width then width = math.min(width, self.opts.max_width) end
  if self.opts.max_height then height = math.min(height, self.opts.max_height) end

  -- leave room for metadata lines above the image
  local pos = self.opts.pos or { 1, 0 }
  height = math.max(1, height - math.max(0, pos[1] - 1))

  local size = util.fit(self.img.file, { width = width, height = height })
  return {
    loc = {
      pos[1],
      pos[2],
      width = size.width,
      height = size.height,
    },
    wins = wins,
  }
end

function M:update()
  if self.closed or not vim.api.nvim_buf_is_valid(self.buf) or not self.img:ready() then return end
  if not self.img.sent then self.img:send() end

  local state = self:state()
  if #state.wins == 0 then return end

  self.img:place(self)
  if terminal.env().placeholders then
    terminal.request {
      a = "p",
      U = 1,
      i = self.img.id,
      p = self.id,
      C = 1,
      c = state.loc.width,
      r = state.loc.height,
    }
    self:render_grid(state.loc)
  else
    self:render_fallback(state)
  end
end

return M
