# Kulala News

## Version 5.2.0

### Feature: [Oauth2 support](https://neovim.getkulala.net/docs/usage/authentication)
### Enhancement: added `Authentication Manager` - `<Leader>Ru`, Environment Manager - `<Leader>Re` and `Request Manager` - `<Leader>Rf`
### Feature: [Websockets support](https://neovim.getkulala.net/docs/usage/websockets)
### Docs: added runnable [demo](https://neovim.getkulala.net/docs/usage/demos) `*.http` examples
### Feature: `import` and `run` [commands](https://neovim.getkulala.net/docs/usage/import-and-run-http) to import and run requests from external `*.http` files
### Enhancement: improved compatibility with IntelliJ HTTP Client spec:

 - URL line support for `absolute/origin/asterisk path`
 - `#` and `//` comments support
 - `GRAPHQL` method support
 
### Enhancement: `win_opts` [config option](https://neovim.getkulala.net/docs/getting-started/configuration-options) to customize Kulala UI properties 

## Version 5.1.0

### Feature: `Cookie:` header support
### Feature: Use `{{vars}}` in [external](https://neovim.getkulala.net/docs/usage/request-variables) json files
### Feature: [Asserts, Automated testing and Reporting](https://neovim.getkulala.net/docs/usage/testing-and-reporting)
### Enhancement: keymaps for `Jump to response` and `Jump to request` in response view
### Feature: [conditional requests](https://neovim.getkulala.net/docs/scripts/request-reference) with `request.skip()` and `request.replay()`
### Enhancement: new [config options:](https://neovim.getkulala.net/docs/getting-started/configuration-options)

  - `request_timeout` - request timeout limit
  - `halt_on_error` - stop on first error when running multiple requests
  - `show_request_summary` - show request summary in response view
  - `debug` - enable|disable|set log level

## Version 5.0.0

### Feature: Request/Response history
### Feature: [GRPC support](https://neovim.getkulala.net/docs/usage/grpc)
### Feature: `default_view` config option can be used to specify custom response handler
### Enhancement: `global_keymaps` config option to set Kulala keymaps
### Feature: run requests from within comments in non-http files
### Feature: run visually selected requests
