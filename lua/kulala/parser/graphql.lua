local Json = require("kulala.utils.json")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

local function parse(body)
  local query_string
  local variables_string

  -- Split the body into lines
  local lines = vim.split(body, "\n")
  local in_query = false
  local in_variables = false
  local query = {}
  local variables = {}
  local query_matcher = "query"
  local mutation_matcher = "mutation"
  local variables_matcher = "{"

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
    end

    line = vim.trim(line)

    if in_query then
      table.insert(query, line)
    elseif in_variables then
      table.insert(variables, line)
    end
  end

  if #query == 0 then
    query_string = nil
  else
    query_string = table.concat(query, " ")
  end

  if #variables == 0 then
    variables_string = nil
  else
    variables_string = table.concat(variables, " ")
  end

  return query_string, variables_string
end

---Get GraphQL JSON from the request body
---@return string|nil, table|nil -- json string, json table
M.get_json = function(body)
  local query, variables = parse(body)
  local json = { query = "" }

  if not (query and #query > 0) then return end

  json.query = query

  if variables then
    local result = Json.parse(variables, { verbose = true })
    if not result then return end

    json.variables = result
  end

  return vim.json.encode(json), json
end

M.format = function(body, opts)
  opts = vim.tbl_extend("keep", opts or {}, { sort = false })

  local path = require("kulala.config").get().contenttypes["text/graphql"]
  path = path and path.formatter and path.formatter[1] or vim.fn.exepath("prettier")

  if vim.fn.executable(path) == 0 then return Logger.warn("Prettier is required to format GRAPHQL") end

  local _, json = M.get_json(body)
  if not json then return body end

  local result = Shell.run({ path, "--stdin-filepath", "graphql", "--parser", "graphql" }, {
    stdin = json.query,
    sync = true,
    err_msg = "Failed to format GraphQL",
    abort_on_stderr = true,
  })

  if not result or result.code ~= 0 or result.stderr ~= "" or result.stdout == "" then return body end
  local formatted = result.stdout

  if json.variables and next(json.variables) then
    formatted = formatted .. "\n" .. Json.format(json.variables, { sort = opts.sort })
  end

  return formatted
end

return M
