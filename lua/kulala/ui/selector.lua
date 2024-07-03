local GLOBAL_STORE = require("kulala.global_store")

local M = {}

function M.select_env()
	if not GLOBAL_STORE.get("http_client_env_json") then
		return
	end

	local envs = {}
	for key, _ in pairs(GLOBAL_STORE.get("http_client_env_json")) do
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

return M
