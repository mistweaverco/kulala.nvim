# Setup Options

The following options can be set in the setup function.

### Full example

Here is a full example of setting up the Kulala plugin with the `setup` function:

```lua title="setup.lua"
require("kulala").setup({
  -- default_view, body or headers or headers_body
  default_view = "body",
  -- dev, test, prod, can be anything
  -- see: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
  default_env = "dev",
  -- enable/disable debug mode
  debug = false,
  -- default formatters for different content types
  formatters = {
    json = { "jq", "." },
    xml = { "xmllint", "--format", "-" },
    html = { "xmllint", "--format", "--html", "-" },
  },
  -- default icons
  icons = {
    inlay = {
      loading = "⏳",
      done = "✅",
      error = "❌",
    },
    lualine = "🐼",
  },
  -- additional cURL options
  -- see: https://curl.se/docs/manpage.html
  additional_curl_options = {},
  -- scratchpad default contents
  scratchpad_default_contents = {
    "@MY_TOKEN_NAME=my_token_value",
    "",
    "POST https://httpbin.org/post HTTP/1.1",
    "accept: application/json",
    "content-type: application/json",
    "# @name scratchpad",
    "",
    "{",
    '  "foo": "bar"',
    "}",
  },
  -- enable winbar
  winbar = false;
})
```

### default_view

Default view.

Possible values:

- `body`
- `headers`
- `headers_body`

Default: `body`

Example:

```lua
require("kulala").setup({
  default_view = "body",
})
```

### default_env

Default environment.

See: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files

Possible values:

- `[any string]`

Default: `dev`

Example:

```lua
require("kulala").setup({
  default_env = "body",
})
```

### debug

Enable debug mode.

Possible values:

- `true`
- `false`

Default: `false`

Example:

```lua
require("kulala").setup({
  debug = false,
})
```

### formatters

Default formatters for different content types.

Possible values:

- `json = [command-table]`
- `xml = [command-table]`
- `html = [command-table]`

Default:

```lua
formatters = {
  json = { "jq", "." },
  xml = { "xmllint", "--format", "-" },
  html = { "xmllint", "--format", "--html", "-" },
}
```

Example:

```lua
require("kulala").setup({
  formatters = {
    json = { "jq", "." },
    xml = { "xmllint", "--format", "-" },
    html = { "xmllint", "--format", "--html", "-" },
  },
})
```

### icons

Default icons.

Possible values:

- `inlay = { loading = [string], done = [string], error = [string] }`
- `lualine = [string]`

Default:

```lua
icons = {
  inlay = {
    loading = "⏳",
    done = "✅"
    error = "❌",
  },
  lualine = "🐼",
}
```

Example:

```lua
require("kulala").setup({
  icons = {
    inlay = {
      loading = "⏳",
      done = "✅"
      error = "❌",
    },
    lualine = "🐼",
  },
})
```

### Additional cURL options

Additional cURL options.

Possible values:

- `[table of strings]`

Default: `{}`

Example:

```lua
require("kulala").setup({
  additional_curl_options = { "--insecure", "-A", "Mozilla/5.0" },
})
```

### scratchpad_default_contents

Scratchpad default contents.

The contents of the scratchpad when it is opened
via `:lua require('kulala').scratchpad()` command.

Possible values:

- `[table of strings]` (each string is a line)

Default:

```lua
scratchpad_default_contents = {
  "@MY_TOKEN_NAME=my_token_value",
  "",
  "POST https://httpbin.org/post HTTP/1.1",
  "accept: application/json",
  "content-type: application/json",
  "# @name scratchpad",
  "",
  "{",
  '  "foo": "bar"',
  "}",
}
```

Example:

```lua
require("kulala").setup({
  scratchpad_default_contents = {
    "@AUTH_USERNAME=my_username",
    "",
    "POST https://httpbin.org/post HTTP/1.1",
    "accept: application/json",
    "content-type: application/json",
    "# @name scratchpad_special_name",
    "",
    "{",
    '  "baz": "qux"',
    "}",
  },
})
```

### winbar

Enable winbar for result buffer

Possible values:

- `true`
- `false`

Default: `false`

Example:

```lua
require("kulala").setup({
  winbar = false,
})
```

