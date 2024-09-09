# Example configuration

This is an example configuration for `kulala`.

This helps you get started with `kulala` and provides a basic configuration to use it.

## Configuration file

Create `ftplugin/http.lua` in your configuration directory.

This file will be loaded when you open a file with the `http` filetype.

### Execute request

Add the following code to `ftplugin/http.lua` to execute the http request when you press Enter.

```lua ftplugin/http.lua
vim.api.nvim_buf_set_keymap(
  0,
  "n",
  "<CR>",
  "<cmd>lua require('kulala').run()<cr>",
  { noremap = true, silent = true }
)
```

### Jump between requests

Add the following code to `ftplugin/http.lua` to jump between requests when you press `]` and `[`.

```lua ftplugin/http.lua
vim.api.nvim_buf_set_keymap(
  0,
  "n",
  "[",
  "<cmd>lua require('kulala').jump_prev()<cr>",
  { noremap = true, silent = true }
)
vim.api.nvim_buf_set_keymap(
  0,
  "n",
  "]",
  "<cmd>lua require('kulala').jump_nevt()<cr>",
  { noremap = true, silent = true }
)
```

### Inspect the current request

Add the following code to `ftplugin/http.lua` to inspect the current request when you press `<leader>i`.

```lua ftplugin/http.lua
vim.api.nvim_buf_set_keymap(
  0,
  "n",
  "<leader>i",
  "<cmd>lua require('kulala').inspect()<cr>",
  { noremap = true, silent = true }
)
```

### Toggle body and headers

Add the following code to `ftplugin/http.lua` to toggle between body and headers when you press `<leader>t`.

```lua ftplugin/http.lua
vim.api.nvim_buf_set_keymap(
  0,
  "n",
  "<leader>t",
  "<cmd>lua require('kulala').toggle_view()<cr>",
  { noremap = true, silent = true }
)
```

### Copy as curl

Add the following code to `ftplugin/http.lua` to copy the current request as a curl command when you press `<leader>co`.

::: tip

Mnemonic: `co` for `curl out`.

:::

```lua ftplugin/http.lua
vim.api.nvim_buf_set_keymap(
  0,
  "n",
  "<leader>co",
  "<cmd>lua require('kulala').copy()<cr>",
  { noremap = true, silent = true }
)
```

### Insert from curl

Add the following code to `ftplugin/http.lua` to insert from a curl command
in your clipboard when you press `<leader>ci`.

::: tip

Mnemonic: `ci` for `curl in`.

:::

```lua ftplugin/http.lua
vim.api.nvim_buf_set_keymap(
  0,
  "n",
  "<leader>ci",
  "<cmd>lua require('kulala').from_curl()<cr>",
  { noremap = true, silent = true }
)
```
