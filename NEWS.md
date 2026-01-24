# Kulala News

## Version 5.3.4

### Feature: `Shared blocks` [Shared blocks](usage/shared-blocks.md)
### Breaking changes: deprecate `curl-global` and `grpc-global` flags in favor of flags in `Shared` block
### Enhancement: add `winbar_labels` and `winbar_labels_keymaps` config options to customize winbar labels [Configuration](getting-started/configuration-options.mdx)
### Feature: support for `custom_dynamic_variables`
### Feature: support `run` command with metadata and without URL [Import and Run](usage/import-and-run-http.md)
### Enhancement: add `@attach-cookie-jar` metadata, `write_cookes` config option [Cookies](usage/cookies.md) and `Open cookies jar` keymap/code action
### Enhancement: include cookies with GRAPQL schema requests
### Enhancement: add `--sub` option to Kulala CLI to provide variable substitutions
### Enhancement: add `split_params` option to formatter [Configuration](getting-started/configuration-options.mdx)
### Enhancement: improve grammar and syntax highlighting for query and form params and values, multipart form data
### Feature: add Electron browser and `Browser CMD` param to `Auth Config` for Oauth2 auth code flow [Authentication](usage/authentication.md)
### Enhancement: content type formatters are regex matched against `Content-Type` header [Automatic Response Formatting](usage/automatic-response-formatting.md)
### Enhancement: add `Custom Headers` to Oauth2 auth requests in `Auth Config` [Authentication](usage/authentication.md)
### Enhancement: `http-client.env.json` and `http-client.private.env.json` files will be searched in parent directories and merged [Dotenv and http-client.env.json support](usage/dotenv-and-http-client.env.json-support.md)
### Enhancement: share headers and post request scripts in Shared blocks [Shared blocks](usage/shared-blocks.md)
### Enhancement: support using `kulala_http` parser without `nvim-treesitter`, i.e. installed by Nix
### Enhancement: support `dot` notation in accessing deep objects from `JS` scripts [JS](scripts/request-reference.md)

## Version 5.3.3

### Breaking change: change HTML formatter to use `prettier` instead of `xmllint`

### Feature: add `urlencode_skip/force` config option, add `[]` to default encoded chars [Configuration](getting-started/configuration-options.mdx)
### Feature: format json response on redirect, add `format_json_on_redirect` config option [Configuration](getting-started/configuration-options.mdx)
### Feature: support importing .graphql files
### Feature: do not display big responses, add `max_response_size` config option [Configuration](getting-started/configuration-options.mdx)
### Feature: add `# @env-stdin-cmd-pre` and `# @stdin-cmd-pre` [Basic Usage](usage/basic-usage.md)
### Feature: add `# @delay` to delay request execution [Basic Usage](usage/basic-usage.md)
### Feature: support LSP in js buffers to complete request/response/client methods

### Enhancement: Mouse support for winbar ui
### Enhancement: add `before_request` hook [Configuration](getting-started/configuration-options.mdx)
### Enhancement: add highlight opts for status icons [Configuration](getting-started/configuration-options.mdx)
### Enhancement: add syntax hl for grpc errors
### Enhancement: support variables in included json files
### Enhancement: optimize formatter, add formatting for graphql, json and scripts
### Enhancement: wrap {{variables}} with quotes in json bodies, add `quote_json_variables` config option, [Configuration](getting-started/configuration-options.mdx)
### Enhancement: support nested "a.b.c" env variables
### Enhancement: support using variables in redirect response directive

### Docs: add recipes for updating variables in `http-client.env.json` [Recipes](usage/recipes.md) 

## Version 5.3.2

### Enhancement: support url encoding in scheme, authority, path
### Feature: support importing .graphql and .gql files
### Enhancement: formatter wraps {{variables}} with quotes in json bodies
### Feature: add `# @secret` metadata to prompt for sensitive data
### Feature: create `http-client.env.json` and `http-client.private.env.json` if not found
### Enhancement: add `Client Credentials` to all grant types
### Enhancement: expand variables in `Security.Auth` configs
### Enhancement: generate bug report on error and with `require("kulala").generate_bug_report()`
### Feature: support `kulala_http` parser in markdown code blocks
### Enhancement: update syntax highlighting for `kulala_http` parser
### Enhancement: add sorting options to [Formatter](getting-started/configuration-options.mdx)
### Enhancement: allow variables in Curl and GRPC flags
### Feature: add LSP diagnostics

## Version 5.3.1

### Enhancement: integrated LSP HTTP formatter
### Enhancement: resolve NODE_PATH to nearest node_modules, add `node_path_resolver` to options
### Feature: GraphQL autocompletion
### Enhancement: execute inline/file scripts in the order of declaration
### Enhancement: add `Expires In` option to `Auth Config`
### Enhancement: option `ui.win_opts` to set custom Kulala UI buffer and window options
### Feature: export requests to [Postman](usage/import-export.md)
### Enhancement: add `import|export` commands to CLI

## Version 5.3.0

### Feature: Scripting `request.iteration()` - current count of replays [Lua](scripts/lua-scripts.md), [JS](scripts/request-reference.md)
### Enhancement: config option `kulala_keymaps_prefix` to set custom prefix for Kulala keymaps
### Enhancement: support `@curl-data-urlencode` flag
### Enhancement: support `SSL Configuration` in `http-client.private.env.json` files
### Enhancement: Oauth2 - `@curl-global` flags and `additional_curl_options` take effect in auth requests
### Enhancement: Oauth2 - add Basic Authorization support for Client Credentials grant type
### Feature: JQ filter [filter](usage/filter-response.md)
### Feature: Kulala Formatter [fmt](usage/basic-usage.md) - format and import requests from Postman/Bruno/OpenAPI
### Feature: Kulala CLI and Kulala CI Github Action [kulala-cli-ci](usage/cli-ci.md)
### Enhancement: unify syntax for naming requests with `###` in favor of `# @name`
### Enhancement: allow `run` to run requests from the same file

## Version 5.2.0

### Enhancement: Kulala LSP [lsp](usage/basic-usage.md) - autocompletion, symbols search and outline, code actions, hover
### Feature: Lua [scripting](scripts/lua-scripts.md)
### Feature: set `Host` in default headers in [http-env.profile.json](usage/dotenv-and-http-client.env.json-support.md) files
### Feature: set `default headers` per environment in [http-env.profile.json](usage/dotenv-and-http-client.env.json-support.md) files
### Feature: per-request and global `@curl` flags [Basic usage](usage/custom-curl-flags.md)
### Feature: [Oauth2 support](usage/authentication.md)
### Enhancement: added request progress status and <C-c> keymap to cancel requests
### Enhancement: added `Authentication Manager` - `<Leader>Ru`, Environment Manager - `<Leader>Re` and `Request Manager` - `<Leader>Rf`
### Feature: [Websockets support](usage/websockets.md)
### Docs: added runnable [demo](usage/demos.mdx) `*.http` examples
### Feature: `import` and `run` [commands](usage/import-and-run-http.md) to import and run requests from external `*.http` files
### Enhancement: improved compatibility with IntelliJ HTTP Client spec: [HTTP File spec](usage/http-file-spec.md)

  - URL line support for `absolute/origin/asterisk path`
  - `#` and `//` comments support
  - `GRAPHQL` method support
  - multi line URL support
 
### Enhancement: `win_opts` [config option](getting-started/configuration-options.mdx) to customize Kulala UI properties 

## Version 5.1.0

### Feature: `Cookie:` header support
### Feature: Use `{{vars}}` in [external](usage/request-variables.md) json files
### Feature: [Asserts, Automated testing and Reporting](usage/testing-and-reporting.md)
### Enhancement: keymaps for `Jump to response` and `Jump to request` in response view
### Feature: [conditional requests](usage/request-reference.md) with `request.skip()` and `request.replay()`
### Enhancement: new [config options:](configuration-options.md)

  - `request_timeout` - request timeout limit
  - `halt_on_error` - stop on first error when running multiple requests
  - `show_request_summary` - show request summary in response view
  - `debug` - enable|disable|set log level

## Version 5.0.0

### Feature: Request/Response history
### Feature: [GRPC support](usage/grpc.md)
### Feature: `default_view` config option can be used to specify custom response handler
### Enhancement: `global_keymaps` config option to set Kulala keymaps
### Feature: run requests from within comments in non-http files
### Feature: run visually selected requests
