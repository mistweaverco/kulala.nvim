# Keymaps

## Global Keymaps

Set to `true` to enable the [default keymaps](default-keymaps.md) and optionally set a prefix for the keymaps, which only applies to default keymaps, but not to your custom keymaps.

```lua
{
  global_keymaps = true
  global_keymaps_prefix = "<leader>R"
  kulala_keymaps_prefix = "",
}
```

### Custom Global Keymaps

```lua
{
  global_keymaps = {
      ["Send request"] = { -- sets global mapping
        "<leader>Rs",
        function() require("kulala").run() end,
        mode = { "n", "v" }, -- optional mode, default is n
        desc = "Send request" -- optional description, otherwise inferred from the key
      },
      ["Send all requests"] = {
        "<leader>Ra",
        function() require("kulala").run_all() end,
        mode = { "n", "v" },
        ft = "http", -- sets mapping for *.http files only
      },
      ["Replay the last request"] = {
        "<leader>Rr",
        function() require("kulala").replay() end,
        ft = { "http", "rest" }, -- sets mapping for specified file types
      },
    ["Find request"] = false -- set to false to disable
  },
}
```

## Kulala Keymaps

Set to `false` to disable the default keymaps.
in the Kulala UI buffer.

```lua
{
  kulala_keymaps = false
}
```

Default is `true`.

### Custom Kulala Keymaps

```lua
{
  kulala_keymaps = {
    ["Show headers"] = { "H", function() require("kulala.ui").show_headers() end, },
  }
  kulala_keymaps = {
    ["Show verbose"] = false -- set false to disable
  }
}
```

### Kulala LSP Keymaps

Kulala LSP does not set any keymaps by default, but relies on Neovim's default LSP keymaps. 

Some distributions, like `AstroNvim`, set these keymaps only for LSPs that have been setup through `nvim-lspconfig` or the distributions's own LSP configs. 
In this case, you may need to enable them yourself.

You can do this, either by enabling the default Kulala's LSP keymaps:
```lua
{
  lsp = {
    keymaps = true, -- enables default Kulala's LSP keymaps
  }
}
```

by customizing them or setting to `false` to disable some or all of them:

```lua
{
  lsp = {
      keymaps = {
        ["<leader>ls"] = { vim.lsp.buf.document_symbol, desc = "Search Symbols" },
        ["<leader>lv"] = { function() Snacks.picker.lsp_symbols({ layout = { preset = "vscode", preview = "main" } }) end, desc = "Search Symbols", }, -- requires snacks.nvim
        ["<leader>lt"] = { "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols outline" }, -- requires trouble.nvim
        ["<leader>lS"] = { function() require("aerial").toggle() end, desc = "Symbols outline", }, -- requires aerial.nvim (recommended)
        ["K"] = { vim.lsp.buf.hover, desc = "Hover" },
        ["<leader>la"] = { vim.lsp.buf.code_action, desc = "Code Action" },
        ["<leader>lf"] = { vim.lsp.buf.format, desc = "Buffer Format" },
      }
    }
}
```
