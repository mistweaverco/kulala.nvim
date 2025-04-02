local content = io.read("*a")

local result = content:gsub("```([%w]+)([^\n]*)\n(.-)\n```", function(lang, file, code)
  local ret = file and #file:gsub("%s*", "") > 0 and file .. "\n" or ""
  ret = ret .. "```" .. lang .. "\n"
  return ret .. code .. "\n```"
end)

io.stdout:write(result)
