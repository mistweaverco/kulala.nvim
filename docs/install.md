## Install

Via [lazy.nvim](https://github.com/folke/lazy.nvim):


### Simple configuration

```lua
require('lazy').setup({
  -- HTTP REST-Client Interface
  {
    'mistweaverco/kulala.nvim'
    config = function()
      require('kulala').setup({
        debug = false, -- Enable debug mode
        default_view = 'body', -- body or headers
      })
    end
  },
})
```
