local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local FORMATTER = require("kulala.formatter")
local FS = require("kulala.utils.fs")

local M = {}

-- runs the cmd and maybe formats the result
M.run = function(result)
	vim.fn.jobstart(result.cmd, {
		on_stdout = function()
			if result.ft then
				local body = FS.read_file(GLOBALS.BODY_FILE)
				FS.write_file(GLOBALS.BODY_FILE, FORMATTER.format(result.ft, body))
			end
		end,
	})
end

return M
