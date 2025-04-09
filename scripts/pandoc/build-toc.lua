local path = "docs/sidebars.ts"
local toc_path = "docs/docs/index.md"

local sidebars = io.open(path, "r")

if not sidebars then return end

local sections = {}
local function section()
  return {
    label = "",
    description = "",
    items = {},
  }
end

print("Generating Table of Contents...")

local current_section = nil
local is_items = false

for line in sidebars:lines() do
  if line:match("^%s*label:") then
    table.insert(sections, current_section)
    current_section = section()
    current_section.label = line:match("^%s*label: ['\"](.*)[\"']")
  elseif line:match("^%s*description:") then
    current_section.description = line:match("^%s*description: [\"'](.*)[\"']")
  elseif line:match("^%s*items:") then
    is_items = true
  elseif is_items then
    table.insert(current_section.items, line:match("^%s*[\"'](.*)[\"']"))
  elseif is_items and line:match("^%s*%]") then
    is_items = false
  end
end

table.insert(sections, current_section)

local template = [[
# Kulala.nvim Documentation

## Table of Contents

]]

for _, section in ipairs(sections) do
  template = template .. "### " .. section.label .. " - "
  template = template .. section.description .. "\n\n"

  for _, item in ipairs(section.items) do
    local file = item:match("/(.*)") .. ".txt"
    local title = file:gsub("-", " "):gsub("^%l", string.upper)
    template = template .. ("- %s [%s](%s)\n\n"):format(title, title, file)
  end
end

io.open(toc_path, "w"):write(template)
sidebars:close()
