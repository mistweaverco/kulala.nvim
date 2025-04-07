# Kulala News

## Version 5.2.0

### Feature: Lua [scripting](scripts/lua-scripts.md)
### Feauture: built-in autocompletion for HTTP syntax, metadata, commands, variables, requests and API
### Feature: set `Host` in default headers in [http-env.profile.json](usage/dotenv-and-http-client.env.json-support) files
### Feature: set `default headers` per environment in [http-env.profile.json](usage/dotenv-and-http-client.env.json-support) files
### Feature: per-request and global `@curl` flags [Basic usage](usage/custom-curl-flags)
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
