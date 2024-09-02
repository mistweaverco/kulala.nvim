local config = require("kulala.config")
local execute_keymap = config.get().execute_keymap or "<CR>"

vim.api.nvim_buf_set_keymap(
  0,
  "n",
  execute_keymap,
  "<cmd>lua require('kulala').run()<cr>",
  { noremap = true, silent = true }
)
