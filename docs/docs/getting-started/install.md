# Install

How to install kulala.

:::warning

Requires Neovim 0.10.0+

:::

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

### Basic configuration

```lua title="init.lua"
require("lazy").setup({
  {
    "mistweaverco/kulala.nvim",
    keys = {
      { "<leader>Rs", desc = "Send request" },
      { "<leader>Ra", desc = "Send all requests" },
      { "<leader>Rb", desc = "Open scratchpad" },
    },
    ft = { "http", "rest" },
    opts = {
      -- your configuration comes here
      global_keymaps = false,
      global_keymaps_prefix = "<leader>R",
      kulala_keymaps_prefix = "",
    },
  },
})
```

:::warning

`opts` needs to be at least an empty table `{}` and can't be completely omitted.

By default global keymaps are disabled, change to `global_keymaps = true` to get a complete set of key mappings for Kulala.  
Check the [keymaps documentation](keymaps.md) for details.

Kulala provides a built-in formatter for HTTP files, which relies on `Kulala-FMT` included as a submodule. 
If your package manager does not support submodules, you may need to fetch it manually.

```sh
git fetch --recurse-submodules
```

:::
