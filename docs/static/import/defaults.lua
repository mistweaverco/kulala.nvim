local M = {
  kulala_core = {
    path = nil,
    timeout = nil,
    data_dir = nil,
  },
  default_env = "default",
  vscode_rest_client_environmentvars = false,

  halt_on_error = true,

  contenttypes = {},

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
