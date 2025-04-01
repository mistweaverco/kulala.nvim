local demojify = require("lib.Demojify")

-- keep track if a emoji was removed previously
local prevEmoji = false

function P(s)
  require("scripts.logging").temp(s)
end

function string.starts_with(str, starts)
  return str:sub(1, #starts) == starts
end

function string.ends_with(str, ends)
  return ends == "" or str:sub(-#ends) == ends
end

local function cleanup(elem)
  -- Don't touch code blocks
  if elem.t == "Code" or elem.t == "CodeBlock" then return elem end
  -- get rid of the space after the emoji, reset
  if elem.t == "Space" and prevEmoji then
    prevEmoji = false
    return {}
  end
  -- only handle things with text contents
  if elem.text ~= nil then
    elem.text = demojify(elem.text)
    if #elem.text ~= 0 then
      if elem.text:starts_with(":") and elem.text:ends_with(":") then
        prevEmoji = true
        return {}
      else
        return elem
      end
    else
      prevEmoji = true
      return {}
    end
  end
end

return { { Inline = cleanup, Block = cleanup } }
