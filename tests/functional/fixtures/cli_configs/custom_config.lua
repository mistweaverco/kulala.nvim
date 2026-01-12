-- Custom config for CLI testing
return {
  default_env = "custom_env",
  request_timeout = 3000,
  halt_on_error = true,
  ui = {
    default_view = "headers",
  },
}
