# Keymaps

## Global Keymaps

Set to `true` to enable the default keymaps.

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
        mode = { "n", "v" }, -- optional mode, default is v
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
}
```
