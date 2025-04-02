local result = ""
local imports = {}
local import_dir = "./docs/static/"

local function get_file(file)
  local f = io.open(imports[file], "r")
  if not f then return end

  local content = f:read("*a")
  f:close()

  return content
end

local function replace_code_block(line)
  local lang = line:match('language="([^"]+)"')
  local file = line:match(">{(.+)}<")
  if not file then return end

  local path = imports[file]
  if not path then return end

  result = result .. path:match("[^/]+$") .. "\n"
  result = result .. "```" .. lang .. "\n"
  result = result .. (get_file(file) or "") .. "\n"
  result = result .. "```\n"
end

for line in io.stdin:lines("*a") do
  if line:match("^import .+ from") then
    local name = line:match("^import (.+) from")
    local filename = line:match('!!raw%-loader!.+/static/(.+)";')

    if filename then imports[name] = import_dir .. filename end
  elseif line:match("<CodeBlock") then
    replace_code_block(line)
  else
    result = result .. line .. "\n"
  end
end

io.stdout:write(result .. "\n")
