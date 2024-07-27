# Install

How to install kulala.

:::warning

Requires Neovim 0.10.0+

:::

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

### Simple configuration

```lua title="init.lua"
require('lazy').setup({
  -- HTTP REST-Client Interface
  {
    'mistweaverco/kulala.nvim'
    config = function()
      require('kulala').setup()
    end
  },
})
```

