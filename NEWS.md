# Kulala News

## Version 5.2.0

### Feature: Websockets support
### Docs: added runnable demo `*.http` examples
### Feature: `import` and `run` commands to import and run requests from external `*.http` files
### Feature: improved compatibility with IntelliJ HTTP Client spec:

 - URL line support for `absolute/origin/asterisk path`
 - `#` and `//` comments support
 - `GRAPHQL` method support

### Enhancement: `win_opts` config option to customize Kulala UI properties

## Version 5.1.0

### Feature: `Cookie:` header support
### Feature: Use `{{vars}}` in external json files
### Assert functions, Reporting section and reporting config options
### Enhancement: keymaps for `Jump to response` and `Jump to request`
### Feature: cognitional requests with `request.skip()` and `request.replay()`
### Enhancement: new config options:

  - `request_timeout` - request timeout limit
  - `halt_on_error` - stop on first error when running multiple requests
  - `show_request_summary` - show request summary in response view
  - `debug` - enable|disable|set log level

## Version 5.0.0

### Feature: Request/Response history
### Feature: GRPC support
### Feature: `default_view` config option can be used to specify custom response handler
### Enhancement: `global_keymaps` config option to set Kulala keymaps
### Feature: run requests from within comments in non-http files
### Feature: run visually selected requests
