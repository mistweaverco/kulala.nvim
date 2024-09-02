# Best Practices

Here are some elegant configurations to use Kulala.

If you haven't found the right habit yet, give it a try.

### Press Enter to execute http request

Create `ftplugin/http.lua` in your configuration directory and add the following lua code.

```lua ftplugin/http.lua
local execute_keymap = "<CR>"

vim.api.nvim_buf_set_keymap(
  0,
  "n",
  execute_keymap,
  "<cmd>lua require('kulala').run()<cr>",
  { noremap = true, silent = true }
)
```
