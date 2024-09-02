--- https://raw.githubusercontent.com/BodneyC/shlex-lua/main/stringreader.lua
--- Adapted from https://gist.github.com/MikuAuahDark/e6428ac49248dd436f67c6c64fcec604
local M = {}
M.__index = M

function M.create(str)
  local o = setmetatable({}, M)

  o.buffer = str or ""
  o.pos = 0
  o.__index = M

  return o
end

function M.read(sr, num)
  if num == "*a" then
    if sr.pos == #sr.buffer then
      return nil
    end

    local out = sr.buffer:sub(sr.pos + 1)

    sr.pos = #sr.buffer
    return out
  elseif num <= 0 then
    return ""
  end

  local out = sr.buffer:sub(sr.pos + 1, sr.pos + num)
  if #out == 0 then
    return nil
  end

  sr.pos = math.min(sr.pos + num, #sr.buffer)
  return out
end

function M.seek(sr, whence, offset)
  whence = whence or "cur"

  if whence == "set" then
    sr.pos = offset or 0
  elseif whence == "cur" then
    sr.pos = sr.pos + (offset or 0)
  elseif whence == "end" then
    sr.pos = #sr.buffer + (offset or 0)
  else
    error("bad argument #1 to 'seek' (invalid option '" .. tostring(whence) .. "')", 2)
  end

  sr.pos = math.min(math.max(sr.pos, 0), #sr.buffer)
  return sr.pos
end

function M.readuntil(sr, phrase, exclude)
  local rest = sr.buffer:sub(sr.pos + 1)
  if not phrase then
    sr.pos = #sr.buffer
    return rest
  end
  local idx = rest:find(phrase, 1, true)
  if not idx then
    return nil
  end
  if exclude then
    idx = idx - 1
  end
  local ret = sr.buffer:sub(sr.pos + 1, sr.pos + idx)
  sr.pos = sr.pos + idx
  return ret
end

function M.readline(sr)
  return sr:readuntil("\n") or sr:readuntil()
end

setmetatable(M, {
  __call = function(_, str)
    return M.create(str)
  end,
})

return M
