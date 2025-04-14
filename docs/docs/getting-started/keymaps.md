# Keymaps

## Global Keymaps

Set to `true` to enable the [default keymaps](default-keymaps.md).

```lua
{
  global_keymaps = true
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

Kulala LSP does not set any keymaps, but relies on your Neovim's default LSP keymaps. Some distributions set these keymaps only for LSPs that have been
setup through `nvim-lspconfig` or the distributions's own LSP config. In this case, you may need to enable them yourself.

```lua
vim.keymap.set("n", "<leader>cs", vim.lsp.buf.document_symbol, { desc = "Search Symbols" })
vim.keymap.set("n", "<leader>cs", function() Snacks.picker.lsp_symbols { layout = { preset = "vscode", preview = "main" } } end, { desc = "Search Symbols" }) -- requires snacks.nvim

vim.keymap.set("n", "<leader>cS", function() require("aerial").toggle() end, { desc = "Symbols outline" }) -- requires aerial.nvim (recommended)
vim.keymap.set("n", "<leader>cS", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols outline" }) -- requires trouble.nvim

vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })
```
