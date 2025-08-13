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

(Only required for formatting GraphQL)

## xmllint

- [xmllint][xmllint] (tested with libxml v20914)

(Only required for formatted XML/HTML responses and
resolving XML request variables)

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

[ts]: https://github.com/nvim-treesitter/nvim-treesitter?tab=readme-ov-file#supported-languages
[xmllint]: https://packages.ubuntu.com/noble/libxml2-utils
