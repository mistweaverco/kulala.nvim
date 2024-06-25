<div align="center">

# kulala.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
![License](https://img.shields.io/github/license/mistweaverco/kulala.nvim?style=for-the-badge)
![Made with Neovim](https://img.shields.io/badge/Made%20with%20Neovim-blue?style=for-the-badge&logo=neovim)
![Project Status](https://img.shields.io/badge/Alpha%20Status-green?style=for-the-badge&logo=github)

[Requirements](#requirements) • [Install](#install) • [Usage](#usage)

<p></p>

A minimal REST-Client Interface for Neovim.

Kulala is swahili for "rest" or "relax".

It allows you to make HTTP requests from within Neovim.

<p></p>

</div>

## Requirements

- [Neovim](https://github.com/neovim/neovim) (tested with 0.10.0)
  - [Treesitter for HTTP](https://github.com/nvim-treesitter/nvim-treesitter?tab=readme-ov-file#supported-languages) (`:TSInstall http`)
- [cURL](https://curl.se/) (tested with 8.5.0)
- [jq](https://stedolan.github.io/jq/) (tested with 1.7)

### Optional requirements

To make things a lot easier,
you can put this lua snippet somewhere in your configuration:

```lua
vim.filetype.add({
  extension = {
    ['http'] = 'http',
  },
})
```

This will make Neovim recognize files
with the `.http` extension as HTTP files.

## Install

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

## Usage

`examples.http`

```http

GET https://pokeapi.co/api/v2/pokemon/ditto
content-type: application/json

###

GET https://swapi-graphql.netlify.app/.netlify/functions/index
content-type: application/json

< ./starwars.graphql

###
```

`starwars.graphql`

```graphql
query {
  allFilms {
    films {
      title
      episodeID
    }
  }
}
```

Place the cursor on the first or the second item
in the `examples.http` and
run `:lua require('kulala').run()`.

For the 
