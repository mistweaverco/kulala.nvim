<div align="center">

![Kulala Logo](logo.svg)

# kulala.nvim

[![Made with love](assets/badge-made-with-love.svg)](https://github.com/mistweaverco/kulala.nvim/graphs/contributors)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/mistweaverco/kulala.nvim?style=for-the-badge)](https://github.com/mistweaverco/kulala.nvim/releases/latest)
[![Discord](assets/badge-discord.svg)](https://discord.gg/QyVQmfY4Rt)

[Requirements](https://neovim.getkulala.net/docs/getting-started/requirements) • [Install](#install) • [Usage](https://neovim.getkulala.net/docs/usage) • [HTTP File Spec](https://neovim.getkulala.net/docs/usage/http-file-spec)

<p></p>

A fully-featured REST Client Interface for Neovim.

Kulala is swahili for "rest" or "relax".

It allows you to make HTTP requests from within Neovim.

<p></p>

![demo](./assets/demo.gif)

<p></p>

## Features
  
Protocols: HTTP, GRPC, GraphQL, WebSocket, Streaming

Specs: HTTP File Spec and IntelliJ HTTP Client compliant

Variables: Environment, Document, Request, Dynamic, Prompt, `http-client.env` files

Importing and running requests from external `*.http` files

Importing and saving request/response data to/from external files

JS and Lua scripting: Pre-request, Post-request, Conditional, Inline, External

Authentication: Basic, Bearer, Digest, NTLM, OAuth2, Negotiate, AWS, SSL

Response formatting and filtering

Assertions, automated testing and reporting

Bulit-in LSP completion and formatting

CLI tooling and CI hooks

Scratchpad: for making requests


#### Together with [Kulala Language Server](https://github.com/mistweaverco/kulala-ls) and [Kulala Formatter](https://github.com/mistweaverco/kulala-fmt), Kulala aims to provide the best REST Client experience on the web without leaving your favourite editor!

We are closely watching products, such as IntelliJ HTTP Client, VS Code REST Client, Postman, Hurl, Bruno, rest.nvim and others for ideas and inspiration and our focus is to 
achieve 100% compatibility with **IntelliJ HTTP Client**, while providing the features of others and more.


#### We love feature requests and feedback, so if you have any ideas or suggestions, please let us know!  

#### We will be happy to implement them ❤️

</div>

## Install

> [!WARNING]
> Requires Neovim 0.10.0+ and cURL.
>
> See [requirements](https://neovim.getkulala.net/docs/getting-started/requirements).

Via [lazy.nvim](https://github.com/folke/lazy.nvim):

### Configuration

```lua
require("lazy").setup({
  {
    "mistweaverco/kulala.nvim",
    keys = {
      { "<leader>Rs", desc = "Send request" },
      { "<leader>Ra", desc = "Send all requests" },
      { "<leader>Rb", desc = "Open scratchpad" },
    },
    ft = {"http", "rest"},
    opts = {
      -- your configuration comes here
      global_keymaps = false,
    },
  },
})
```

> [!WARNING]
>`opts` needs to be at least an empty table `{}` and can't be completely omitted.

> [!NOTE]
> By default global keymaps are disabled, change to `global_keymaps = true` to get a complete set of key mappings for Kulala. Check the [keymaps documentation](https://neovim.getkulala.net/docs/getting-started/keymaps) for details.

See complete [configuration options](https://neovim.getkulala.net/docs/getting-started/configuration-options) for more information.

## Honorable mentions

### rest.nvim

For getting this project started.

This project was heavily inspired by the idea of having a REST client in Neovim.

The actual state of [rest.nvim](https://github.com/rest-nvim/rest.nvim)
as archived kicked off the development of kulala.nvim.

> [!NOTE]
> The project has been [un-archived][restnvim-unarchived-post] again,
> so check it out if you're looking for an alternative.

### curl.nvim

If you want a simple scratchpad for making HTTP requests,
check out [curl.nvim](https://github.com/oysandvik94/curl.nvim)

It's very different to this project, but it's a great tool for making
HTTP requests from within Neovim and maybe just your cup of tea.

### httpbin.org

For providing a great service for testing HTTP requests and
making it in all the kulala examples.

Thanks for making it easy to test and develop this plugin.

[restnvim-unarchived-post]: https://github.com/rest-nvim/rest.nvim/issues/398#issue-2442747909
