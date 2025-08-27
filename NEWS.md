# Kulala News

## Version 5.3.3

### Enhancement: add opts `urlencode_skip` and `urlencode_force` to specify which variables to skip/force url encoding
### Feature: add `# @delay` to delay request execution
### Feature: add `# @env-stdin-cmd-pre` and `# @stdin-cmd-pre` to run shell commands before requests
### Feature: support Kulala LSP auto completion in external scripts
### Feature: support variables in redirect response path
### Feature: do not display big responses + `max_response_size` config option
### Feature: format json response on redirect

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
