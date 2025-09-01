# Requirements

List of requirements for using kulala.

## Neovim

- [Neovim](https://github.com/neovim/neovim) 0.10.0+

### Syntax Highlighting

- [Treesitter for HTTP syntax][ts]

## cURL

- [cURL](https://curl.se/) (tested with 8.5.0)

## gRPCurl

- [gRPCurl](https://github.com/fullstorydev/grpcurl) for GRPC requests

## Websocat

- [Websocat](https://github.com/vi/websocat) for WebSocket requests

## OpenSSL

- Required for JWT and PKCE signing (comes preinstalled with macOS and most Linux distributions and is part of git installation on Windows)

## jq

- [jq](https://stedolan.github.io/jq/) (tested with 1.7)

(Only required for formatted JSON responses)

## prettier

- [prettier](https://prettier.io) 
- [prettierd](https://github.com/fsouza/prettierd) - preferred for better performance

(Required for formatting HTML, JS, GraphQL)

## xmllint

- [xmllint][xmllint] (tested with libxml v20914)

(Only required for formatted XML/HTML responses and
resolving XML request variables)

## stylua

- [stylua](https://github.com/JohnnyMorganz/StyLua)

(Required for Lua scripts)

# Optional Requirements

To make things a lot easier,
you can put this lua snippet somewhere in your configuration:

```lua
vim.filetype.add({
  extension = {
    ['http'] = 'http',
  },
})
```

This will make Neovim recognize files with the `.http` extension as HTTP files.

[ts]: https://github.com/nvim-treesitter/nvim-treesitter

Kulala.nvim comes with a parser compiled with the latest version of treesitter. 

If you have Neovim `0.10.x`, you might get an error `ABI version mismatch for kulala_http.so: supported between 13 and 14, found 15`.

You need to install `tree-sitter CLI` and recompile the parser:

1. Delete the existing parser at `nvim-treesitter/parser/kulala_http`
2. Install the `tree-sitter CLI` (if not installed already):
    - from distribution repositories
    - or from https://github.com/tree-sitter/tree-sitter/tree/master/crates/cli
3. Recompile the parser:
    - Open a  `http` file in Neovim (this will load Kulala)
    - Run `:TSInstallFromGrammar kulala_http`
   
[xmllint]: https://packages.ubuntu.com/noble/libxml2-utils
