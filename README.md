<div align="center">

![Kulala Logo](logo.svg)

# kulala.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/mistweaverco/kulala.nvim?style=for-the-badge)](https://github.com/mistweaverco/kulala.nvim/releases/latest)
[![Discord](https://img.shields.io/badge/discord-join-7289da?style=for-the-badge&logo=discord)](https://discord.gg/QyVQmfY4Rt)

[Requirements](https://kulala.mwco.app/#/requirements) • [Install](#install) • [Usage](https://kulala.mwco.app/#/usage) • [HTTP File Spec](https://kulala.mwco.app/#/http_file_spec)

<p></p>

A minimal REST-Client Interface for Neovim.

Kulala is swahili for "rest" or "relax".

It allows you to make HTTP requests from within Neovim.

<p></p>

![demo](https://github.com/mistweaverco/kulala.nvim/assets/1384938/d3b1e6a6-b91d-4572-a4f0-8a9aa26696d9)

<p></p>

</div>

## Install

> [!WARNING]
> Requires Neovim 0.10.0+

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

### Configuration

```lua
require('lazy').setup({
  -- HTTP REST-Client Interface
  {
    'mistweaverco/kulala.nvim',
    config = function()
      -- Setup is required, even if you don't pass any options
      require('kulala').setup({
        -- default_view, body or headers
        default_view = "body",
        -- dev, test, prod, can be anything
        -- see: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
        default_env = "dev",
        -- enable/disable debug mode
        debug = false,
        -- default formatters for different content types
        formatters = {
          json = { "jq", "." },
          xml = { "xmllint", "--format", "-" },
          html = { "xmllint", "--format", "--html", "-" },
        },
        -- default icons
        icons = {
          inlay = {
            loading = "⏳",
            done = "✅ "
          },
          lualine = "🐼",
        },
        -- additional cURL options
        -- e.g. { "--insecure", "-A", "Mozilla/5.0" }
        additional_curl_options = {},
      })
    end
  },
})
```
