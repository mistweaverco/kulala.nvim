local GLOBAL_STORE = require("kulala.global_store")
local FS = require("kulala.utils.fs")

local M = {}

function M.select_env()
  if not GLOBAL_STORE.get("http_client_env") then
    return
  end

  local envs = {}
  for key, _ in pairs(GLOBAL_STORE.get("http_client_env")) do
    table.insert(envs, key)
  end

  local opts = {
    prompt = "Select env",
  }
  vim.ui.select(envs, opts, function(result)
    if not result then
      return
    end
    GLOBAL_STORE.set("selected_env", result)
    vim.g.kulala_selected_env = result
  end)
end

M.search = function()
  local files = FS.find_all_http_files()
  if #files == 0 then
    return
  end
  vim.ui.select(files, { prompt = "Search" }, function(result)
    if not result then
      return
    end
    vim.cmd("e " .. result)
  end)
end

return M
