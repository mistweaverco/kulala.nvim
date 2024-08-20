local FS = require("kulala.utils.fs")

local M = {}

local plugin_tmp_dir = FS.get_plugin_tmp_dir()

M.VERSION = "3.4.0"
M.UI_ID = "kulala://ui"
M.SCRATCHPAD_ID = "kulala://scratchpad"
M.HEADERS_FILE = plugin_tmp_dir .. "/headers.txt"
M.BODY_FILE = plugin_tmp_dir .. "/body.txt"
M.COOKIES_JAR_FILE = plugin_tmp_dir .. "/cookies.txt"

return M
