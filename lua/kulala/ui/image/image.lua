local terminal = require("kulala.ui.image.terminal")
local util = require("kulala.ui.image.util")

---@class kulala.Image
---@field file string
---@field id number
---@field sent? boolean
---@field placements table<number, kulala.image.Placement>
local M = {}
M.__index = M

local NVIM_ID_BITS = 10
local CHUNK_SIZE = 4096
local _id = 30
local _pid = 10
local nvim_id = 0
local images = {} ---@type table<string, kulala.Image>

---@param file string
---@return kulala.Image
function M.new(file)
  file = vim.fs.normalize(file)
  if images[file] then return images[file] end

  local self = setmetatable({}, M)
  self.file = file
  images[file] = self
  _id = _id + 1

  local bit = require("bit")
  if nvim_id == 0 then
    local pid = vim.fn.getpid()
    nvim_id = bit.band(bit.bxor(pid, bit.rshift(pid, 5), bit.rshift(pid, NVIM_ID_BITS)), 0x3FF)
  end
  self.id = bit.bor(bit.lshift(nvim_id, 24 - NVIM_ID_BITS), _id)
  self.placements = {}
  return self
end

function M:ready()
  return self.file and vim.fn.filereadable(self.file) == 1
end

function M:send()
  if self.sent then return end
  assert(self:ready(), "Image file not readable: " .. tostring(self.file))
  self.sent = true

  if not terminal.env().remote then
    terminal.request {
      t = "f",
      i = self.id,
      f = 100,
      data = util.base64(self.file),
    }
  else
    local fd = assert(io.open(self.file, "rb"), "Failed to open file: " .. self.file)
    local data = fd:read("*a")
    fd:close()
    data = util.base64(data)
    local offset = 1
    while offset <= #data do
      local chunk = data:sub(offset, offset + CHUNK_SIZE - 1)
      local first = offset == 1
      offset = offset + CHUNK_SIZE
      local last = offset > #data
      if first then
        terminal.request {
          t = "d",
          i = self.id,
          f = 100,
          m = last and 0 or 1,
          data = chunk,
        }
      else
        terminal.request {
          m = last and 0 or 1,
          data = chunk,
        }
      end
    end
  end

  for _, placement in pairs(self.placements) do
    placement:update()
  end
end

---@param placement kulala.image.Placement
function M:place(placement)
  if not placement.id then
    _pid = _pid + 1
    placement.id = _pid
  end
  self.placements[placement.id] = placement
  if not self.sent and self:ready() then self:send() end
end

---@param pid? number
function M:del(pid)
  if pid then
    if self.placements[pid] then
      terminal.request { a = "d", d = "i", i = self.id, p = pid }
      self.placements[pid] = nil
    end
  else
    for id in pairs(self.placements) do
      terminal.request { a = "d", d = "i", i = self.id, p = id }
      self.placements[id] = nil
    end
  end
  if not next(self.placements) then terminal.request { a = "d", d = "i", i = self.id } end
end

function M.clear()
  images = {}
end

return M
