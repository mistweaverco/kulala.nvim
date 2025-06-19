local M = {
  default_env = "dev",

  request_timeout = nil,
  halt_on_error = false,

  lsp = { enable = false },

  ui = {
    default_view = "body",
    -- enable/disable request summary in the output window
    show_request_summary = true,
    -- disable notifications of script output
    disable_script_print_output = true,

    report = {
      -- possible values: true | false | "on_error"
      show_script_output = true,
      -- possible values: true | false | "on_error" | "failed_only"
      show_asserts_output = true,
      -- possible values: true | false | "on_error"
      show_summary = true,

      headersHighlight = "Special",
      successHighlight = "String",
      errorHighlight = "ErrorMsg",
    },
  },
}

return M
