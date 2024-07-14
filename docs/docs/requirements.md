# Requirements

### Neovim

- [Neovim](https://github.com/neovim/neovim) 0.10.0+
  - [Treesitter for HTTP](https://github.com/nvim-treesitter/nvim-treesitter?tab=readme-ov-file#supported-languages) (`:TSInstall http`)

### cURL

- [cURL](https://curl.se/) (tested with 8.5.0)

### jq

- [jq](https://stedolan.github.io/jq/) (tested with 1.7) (Only required for formatted JSON responses)

### xmllint

- [xmllint](https://packages.ubuntu.com/noble/libxml2-utils) (tested with libxml v20914) (Only required for formatted XML/HTML responses)

#### Optional Requirements

To make things a lot easier, you can put this lua snippet somewhere in your configuration:

```lua
vim.filetype.add({
  extension = {
    ['http'] = 'http',
  },
})
```

This will make Neovim recognize files with the `.http` extension as HTTP files.

> Custom keymappings will make your life easier.
> Here is an example of how you can set it up.

- Create `ftplugin` directory inside `~/.config/nvim`.
- Inside `ftplugin` directory create a file `http.lua`.
- Inside `http.lua` define a key mapping for running kulala.

```lua
vim.api.nvim_set_keymap("n", "<C-k>", ":lua require('kulala').jump_prev()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-j>", ":lua require('kulala').jump_next()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-l>", ":lua require('kulala').run()<CR>", { noremap = true, silent = true })
```

This will allow you to:

- run `kulala` by pressing `Ctrl + l` in normal mode.
- jump to the previous request by pressing `Ctrl + j` in normal mode.
- jump to the next request by pressing `Ctrl + k` in normal mode.
