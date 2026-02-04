-- Config with deeply nested values for testing
return {
  default_env = "nested_env",
  ui = {
    default_view = "body",
    show_request_summary = true,
    report = {
      show_script_output = false,
      show_asserts_output = "failed_only",
      successHighlight = "CustomGreen",
      errorHighlight = "CustomRed",
    },
  },
}
