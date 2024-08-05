local FS = require("kulala.utils.fs")

local M = {}

M.VERSION = "2.9.0"
M.UI_ID = "kulala://ui"
M.SCRATCHPAD_ID = "kulala://scratchpad"
M.HEADERS_FILE = FS.get_plugin_tmp_dir() .. "/headers.txt"
M.BODY_FILE = FS.get_plugin_tmp_dir() .. "/body.txt"
M.FILETYPE_FILE = FS.get_plugin_tmp_dir() .. "/ft.txt"

return M
