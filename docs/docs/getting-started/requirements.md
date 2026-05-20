# Requirements

List of requirements for using kulala.

## Neovim

- [Neovim](https://github.com/neovim/neovim) 0.10.0+

### Syntax Highlighting

- [Treesitter for HTTP syntax][ts]

## kulala-core

- [kulala-core](https://github.com/mistweaverco/kulala-core)
will automatically download a precompiled binary for
your platform and architecture on first run.

If you want to use a custom build of kulala-core,
make sure to set `kulala_core.path` in your Kulala setup.

kulala-core handles HTTP (embedded cURL),
gRPC (`@grpc/grpc-js`),
WebSockets (native client),
OAuth token requests, and crypto (JWT / PKCE).

You don't need separate `curl`, `grpcurl`, `websocat`, or `openssl`
installs for Kulala itself.

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

(Only required for formatting Lua in `.http` files, not for running scripts)

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

1. Delete the existing parser at `vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser", "kulala_http")`
2. Install the `tree-sitter CLI` (if not installed already):
    - from distribution repositories
    - via npm: `npm install -g tree-sitter-cli`
    - via [Zana](https://getzana.net)
    - or from https://github.com/tree-sitter/tree-sitter/tree/master/crates/cli
3. Recompile the parser:
    - Open a  `http` file in Neovim (this will load Kulala)
      and kick off the compilation automatically
   
[xmllint]: https://packages.ubuntu.com/noble/libxml2-utils
