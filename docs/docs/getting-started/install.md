# Install

How to install kulala.

:::warning

Requires Neovim 0.10.0+

:::

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

### Basic configuration

```lua title="init.lua"
require('lazy').setup({
  -- HTTP REST-Client Interface
  {
    'mistweaverco/kulala.nvim',
    opts = {}
  },
})
```

:::warning

`opts` needs to be at least an empty table `{}` and can't be completely omitted.

:::
