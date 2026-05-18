local M = {
  kulala_core_path = nil,
  kulala_core_timeout = nil,
  kulala_core_data_dir = nil,
  environment_scope = "b",
  default_env = "dev",
  vscode_rest_client_environmentvars = false,

  variables_scope = "document",
  custom_dynamic_variables = {},

  halt_on_error = true,

  certificates = {},

  urlencode = "always",
  urlencode_skip = "",
  urlencode_force = "",

  write_cookies = true,
  infer_content_type = true,

  contenttypes = {},

  format_json_on_redirect = true,
  before_request = true,

  ui = {},

  lsp = {
    enable = true,
    filetypes = { "http", "rest", "json", "yaml", "bruno" },
    keymaps = false,
    formatter = {},
    on_attach = nil,
  },

  debug = 3,
  generate_bug_report = false,
  global_keymaps = false,
  global_keymaps_prefix = "<leader>R",
  kulala_keymaps = true,
  kulala_keymaps_prefix = "",
}

return M
