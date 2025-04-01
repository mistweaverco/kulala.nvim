local inspect = require("inspect")
local import_dir = "./docs/static/"

local is_code_block
local is_import = 0
local block_no = 0
local imports = {}

local function include(elem)
  if not elem.text then return elem end

  if elem.text:match("^import") then
    is_import = 1
  elseif is_import > 0 then
    if is_import == 3 then
      table.insert(imports, elem.text:match("static/(.+)"))
    elseif elem.text == ";" then
      is_import = -1
    end
    is_import = is_import + 1
  elseif elem.text:match("<CodeBlock") then
    is_code_block = true
  elseif is_code_block and elem.t == "Str" then
    ---
  elseif elem.text:match("</CodeBlock>") then
    is_code_block = nil
  elseif elem.t:match("CodeBlock") and elem.text == "" then
    block_no = block_no + 1

    local file = imports[block_no]
    if not file then return elem end
    file = import_dir .. file

    local status, import_file = pcall(io.input, file)
    if not status or not import_file then return end

    elem.text = import_file:read("*a")
    return elem
  end

  return {}
end

local function skip() end

return { { Inline = include }, { Block = include } }
