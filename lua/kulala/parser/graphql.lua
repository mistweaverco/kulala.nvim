local M = {}

local function parse(body)
  local lines = vim.split(body, "\r\n")
  local in_query = false
  local in_variables = false
  local query = {}
  local variables = {}
  local query_matcher = "query"
  local mutation_matcher = "mutation"
  local variables_matcher = "variables "
  local variables_matcher_len = #variables_matcher

  for _, line in ipairs(lines) do
    if line:find("^" .. query_matcher) then
      in_query = true
      in_variables = false
    elseif line:find("^" .. mutation_matcher) then
      in_query = true
      in_variables = false
    elseif line:find("^" .. variables_matcher) then
      in_query = false
      in_variables = true
      line = line:sub(variables_matcher_len + 1)
    end
    if in_query then
      table.insert(query, line)
    elseif in_variables then
      table.insert(variables, line)
    end
  end

  if #query == 0 then
    query = nil
  else
    query = table.concat(query, " ")
  end

  if #variables == 0 then
    variables = nil
  else
    variables = table.concat(variables, " ")
  end

  return query, variables
end

M.get_json = function(body)
  local query, variables = parse(body)
  local json = {}
  json.query = ""
  json.variables = ""

  if query then
    json.query = query
  end

  if variables then
    json.variables = vim.fn.json_decode(variables)
  end

  if #json.query == 0 then
    return nil
  end

  return vim.fn.json_encode(json)
end

return M
