local FS = require("kulala.utils.fs")

local M = {}

M.VERSION = "3.1.3"
M.UI_ID = "kulala://ui"
M.SCRATCHPAD_ID = "kulala://scratchpad"
M.HEADERS_FILE = FS.get_plugin_tmp_dir() .. "/headers.txt"
M.BODY_FILE = FS.get_plugin_tmp_dir() .. "/body.txt"

return M
