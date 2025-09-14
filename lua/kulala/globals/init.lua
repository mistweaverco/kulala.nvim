local FS = require("kulala.utils.fs")

local M = {}

local plugin_tmp_dir = FS.get_plugin_tmp_dir()

M.VERSION = "5.3.3"
M.UI_ID = "kulala://ui"
M.SCRATCHPAD_ID = "kulala://scratchpad"
M.HEADERS_FILE = plugin_tmp_dir .. "/headers.txt"
M.BODY_FILE = plugin_tmp_dir .. "/body.txt"
M.STATS_FILE = plugin_tmp_dir .. "/stats.json"
M.REQUEST_FILE = plugin_tmp_dir .. "/request.json"
M.COOKIES_JAR_FILE = plugin_tmp_dir .. "/cookies.txt"
M.SCRIPT_PRE_OUTPUT_FILE = plugin_tmp_dir .. "/pre-script-output.txt"
M.SCRIPT_POST_OUTPUT_FILE = plugin_tmp_dir .. "/post-script-output.txt"
M.ASSERT_OUTPUT_FILE = plugin_tmp_dir .. "/request_asserts.json"
M.SETTINGS_FILE = vim.fn.stdpath("state") .. "/kulala/settings.json"

return M
