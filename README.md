# kulala.nvim

<div align="center">

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

</div>

A minimal REST-Client Interface for Neovim.

Kulala is swahili for "rest" or "relax".

It allows you to make HTTP requests from within Neovim.

## Requirements

- [Neovim](https://github.com/neovim/neovim) (tested with 0.10.0)
- [cURL](https://curl.se/) (tested with 8.5.0)

## Installation

Via [lazy.nvim](https://github.com/folke/lazy.nvim):


### Simple configuration

```lua
require('lazy').setup({
  -- HTTP REST-Client Interface
  { 'mistweaverco/kulala.nvim' },
})
```

## Public methods

### `require('kulala').run()`

Run the current request.
