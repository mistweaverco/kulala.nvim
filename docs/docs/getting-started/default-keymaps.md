# Default Keymaps

By default, global keymaps are disabled, change to `global_keymaps = true` in the options to enable the complete set of key mappings for Kulala.  
Check the [keymaps documentation](keymaps.md) for details on how to customize keymaps and disable the default keymaps.

Below is the list of available functions and their mappings.
By default, global keymaps are prefixed with `<leader>R`, which can be changed with the `global_keymaps_prefix` option.

Global keymaps are available in all buffers, while Kulala keymaps are available in the Kulala UI buffer only.  
Keymaps with `ft` set will only be available in buffers with the specified filetype.

### Global and ft Keymaps

```lua
  ["Open scratchpad"] = { "b", function() require("kulala").scratchpad() end, },
  ["Open kulala"] = { "o", function() require("kulala").open() end, },

  ["Toggle headers/body"] = { "t", function() require("kulala").toggle_view() end, ft = { "http", "rest" }, },
  ["Show stats"] = { "S", function() require("kulala").show_stats() end, ft = { "http", "rest" }, },

  ["Close window"] = { "q", function() require("kulala").close() end, ft = { "http", "rest" }, },

  ["Copy as cURL"] = { "c", function() require("kulala").copy() end, ft = { "http", "rest" }, },
  ["Paste from curl"] = { "C", function() require("kulala").from_curl() end, ft = { "http", "rest" }, },

  ["Send request"] = { "s", function() require("kulala").run() end, mode = { "n", "v" }, },
  ["Send request <cr>"] = { "<CR>", function() require("kulala").run() end, mode = { "n", "v" }, ft = { "http", "rest" }, },
  ["Send all requests"] = { "a", function() require("kulala").run_all() end, mode = { "n", "v" }, },

  ["Inspect current request"] = { "i", function() require("kulala").inspect() end, ft = { "http", "rest" } },
  ["Open cookies jar"] = { "j", function() require("kulala").open_cookies_jar() end, ft = { "http", "rest" } },
  ["Replay the last request"] = { "r", function() require("kulala").replay() end, },

  ["Find request"] = { "f", function() require("kulala").search() end, ft = { "http", "rest" }, },
  ["Jump to next request"] = { "n", function() require("kulala").jump_next() end, ft = { "http", "rest" }, },
  ["Jump to previous request"] = { "p", function() require("kulala").jump_prev() end, ft = { "http", "rest" }, },

  ["Select environment"] = { "e", function() require("kulala").set_selected_env() end, ft = { "http", "rest" }, },
  ["Manage Auth Config"] = { "u", function() require("lua.kulala.ui.auth_manager").open_auth_config() end, ft = { "http", "rest" }, },
  ["Download GraphQL schema"] = { "g", function() require("kulala").download_graphql_schema() end, ft = { "http", "rest" }, },

  ["Clear globals"] = { "x", function() require("kulala").scripts_clear_global() end, ft = { "http", "rest" },
  ["Clear cached files"] = { "X", function() require("kulala").clear_cached_files() end, ft = { "http", "rest" }, },
```

### Kulala UI keymaps

```lua
  ["Show headers"] = { "H", function() require("kulala.ui").show_headers() end, },
  ["Show body"] = { "B", function() require("kulala.ui").show_body() end, },
  ["Show headers and body"] = { "A", function() require("kulala.ui").show_headers_body() end, },
  ["Show verbose"] = { "V", function() require("kulala.ui").show_verbose() end, },

  ["Show script output"] = { "O", function() require("kulala.ui").show_script_output() end, },
  ["Show stats"] = { "S", function() require("kulala.ui").show_stats() end, },
  ["Show report"] = { "R", function() require("kulala.ui").show_report() end, },
  ["Show filter"] = { "F", function() require("kulala.ui").toggle_filter() end },

  ["Send WS message"] = { "<S-CR>", function() require("kulala.cmd.websocket").send() end, mode = { "n", "v" }, },
  ["Interrupt requests"] = { "<C-c>", function() require("kulala.cmd.websocket").close() end, desc = "also: CLose WS connection" },

  ["Next response"] = { "]", function() require("kulala.ui").show_next() end, },
  ["Previous response"] = { "[", function() require("kulala.ui").show_previous() end, },
  ["Jump to response"] = { "<CR>", function() require("kulala.ui").jump_to_response() end, desc = "also: Send WS message for WS connections" },

  ["Clear responses history"] = { "X", function() require("kulala.ui").clear_responses_history() end, },

  ["Show help"] = { "?", function() require("kulala.ui").show_help() end, },
  ["Show news"] = { "g?", function() require("kulala.ui").show_news() end, },

  ["Toggle split/float"] = { "|", function() require("kulala.ui").toggle_display_mode() end, prefix = false, },
  ["Close"] = { "q", function() require("kulala.ui").close_kulala_buffer() end, },
```

### Kulala LSP Keymaps

```lua
  ["<leader>ls"] = { vim.lsp.buf.document_symbol, desc = "Search Symbols" },
  ["<leader>lv"] = { function() Snacks.picker.lsp_symbols({ layout = { preset = "vscode", preview = "main" } }) end, desc = "Search Symbols", }, -- requires snacks.nvim
  ["<leader>lt"] = { "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols outline" }, -- requires trouble.nvim
  ["<leader>lS"] = { function() require("aerial").toggle() end, desc = "Symbols outline", }, -- requires aerial.nvim (recommended)
  ["K"] = { vim.lsp.buf.hover, desc = "Hover" },
  ["<leader>la"] = { vim.lsp.buf.code_action, desc = "Code Action" },
  ["<leader>lf"] = { vim.lsp.buf.format, desc = "Buffer Format" },
```
