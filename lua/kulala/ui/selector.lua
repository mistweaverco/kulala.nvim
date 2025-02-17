local DB = require("kulala.db")
local Parser = require("kulala.parser.document")
local ParserUtils = require("kulala.parser.utils")

local M = {}

function M.select_env()
  local http_client_env = DB.find_unique("http_client_env")
  if not http_client_env then return end

  local envs = {}
  for key, _ in pairs(http_client_env) do
    if key ~= "$schema" and key ~= "$shared" then table.insert(envs, key) end
  end

  local opts = {
    prompt = "Select env",
  }
  vim.ui.select(envs, opts, function(result)
    if not result then return end
    vim.g.kulala_selected_env = result
  end)
end

M.search = function()
  local _, requests = Parser.get_document()

  if requests == nil then return end

  local line_starts = {}
  local names = {}

  for _, request in ipairs(requests) do
    local request_name = ParserUtils.get_meta_tag(request, "name")
    if request_name ~= nil then
      table.insert(names, request_name)
      line_starts[request_name] = request.start_line
    end
  end
  if #names == 0 then return end
  vim.ui.select(names, { prompt = "Search" }, function(result)
    if not result then return end
    vim.cmd("normal! " .. line_starts[result] + 1 .. "G")
  end)
end

return M
