## Requirements

### Neovim

- [Neovim](https://github.com/neovim/neovim) (tested with 0.10.0)
  - [Treesitter for HTTP](https://github.com/nvim-treesitter/nvim-treesitter?tab=readme-ov-file#supported-languages) (`:TSInstall http`)

### cURL

- [cURL](https://curl.se/) (tested with 8.5.0)

### jq

- [jq](https://stedolan.github.io/jq/) (tested with 1.7)

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
