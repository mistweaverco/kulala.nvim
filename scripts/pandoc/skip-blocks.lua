function dump(s)
  io.stderr:write(require("scripts.inspect").inspect(s) .. "\n")
  -- io.stderr:write(pandoc.utils.stringify(s) .. "\n")
end

local pandoc = _G.pandoc

function P(s)
  require("scripts.logging").temp(s)
end

local COMMENT = false
local IGNORE_RAWBLOCKS = true

local List = require("pandoc.List")

function Blocks(blocks)
  for i = #blocks - 1, 1, -1 do
    if blocks[i].t == "Null" then blocks:remove(i) end
  end
  return blocks
end

function string.starts_with(str, starts)
  return str:sub(1, #starts) == starts
end

function string.ends_with(str, ends)
  return ends == "" or str:sub(-#ends) == ends
end

function RawBlock(el)
  local str = el.text
  if str == "<!-- panvimdoc-ignore-start -->" then
    COMMENT = true
    return pandoc.List()
  elseif str == "<!-- panvimdoc-ignore-end -->" then
    COMMENT = false
    return pandoc.List()
  end
  if
    (
      string.starts_with(str, "<!-- panvimdoc-include-comment ")
      or string.starts_with(str, "<!-- panvimdoc-include-comment\n")
    ) and string.ends_with(str, "-->")
  then
    local content = string.match(str, "<!%-%- panvimdoc%-include%-comment%s+(.+)%-%->")
    return pandoc.read(content, "markdown").blocks
  end
  if string.starts_with(str, "<!--") then
    return pandoc.List()
  elseif COMMENT == true then
    return pandoc.List()
  else
    return el
  end
end

function Header(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function Para(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function BlockQuote(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function Table(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function Plain(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function OrderedList(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function BulletList(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function LineBlock(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function HorizontalRule(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function Div(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function DefinitionList(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function CodeBlock(el)
  if COMMENT == true then return pandoc.List() end
  return el
end

function Str(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Cite(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Code(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Emph(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Image(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function LineBreak(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Link(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Math(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Note(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Quoted(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function RawInline(el)
  local str = el.text
  if str == "<!-- panvimdoc-ignore-start -->" then
    COMMENT = true
    return pandoc.Str("")
  elseif str == "<!-- panvimdoc-ignore-end -->" then
    COMMENT = false
    return pandoc.Str("")
  end
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function SmallCaps(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function SoftBreak(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Space(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Span(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Text(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Strikeout(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Strong(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Subscript(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Superscript(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end

function Underline(el)
  if COMMENT == true then return pandoc.Str("") end
  return el
end
