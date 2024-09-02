# Configuration Options

Kulala can be configured with the following options.

### Full example

Here is a full example of setting up the Kulala plugin with the available `opts`:

```lua title="kulala.lua"
{
  "mistweaverco/kulala.nvim",
  opts = {
    -- split direction
    -- possible values: "vertical", "horizontal"
    split_direction = "vertical",

    -- default_view, body or headers or headers_body
    default_view = "body",

    -- dev, test, prod, can be anything
    -- see: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
    default_env = "dev",

    -- enable/disable debug mode
    debug = false,

    -- default formatters/pathresolver for different content types
    contenttypes = {
      ["application/json"] = {
        ft = "json",
        formatter = { "jq", "." },
        pathresolver = require("kulala.parser.jsonpath").parse,
      },
      ["application/xml"] = {
        ft = "xml",
        formatter = { "xmllint", "--format", "-" },
        pathresolver = { "xmllint", "--xpath", "{{path}}", "-" },
      },
      ["text/html"] = {
        ft = "html",
        formatter = { "xmllint", "--format", "--html", "-" },
        pathresolver = {},
      },
    },

    -- can be used to show loading, done and error icons in inlay hints
    -- possible values: "on_request", "above_request", "below_request", or nil to disable
    -- If "above_request" or "below_request" is used, the icons will be shown above or below the request line
    -- Make sure to have a line above or below the request line to show the icons
    show_icons = "on_request",

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
      "# @name scratchpad",
      "POST https://httpbin.org/post HTTP/1.1",
      "accept: application/json",
      "content-type: application/json",
      "",
      "{",
      '  "foo": "bar"',
      "}",
    },

    -- enable winbar
    winbar = false,

    -- Specify the panes to be displayed by default
    -- Current avaliable pane contains { "body", "headers", "headers_body", "script_output" },
    default_winbar_panes = { "body", "headers", "headers_body" },

    -- enable reading vscode rest client environment variables
    vscode_rest_client_environmentvars = false,

    -- disable the vim.print output of the scripts
    -- they will be still written to disk, but not printed immediately
    disable_script_print_output = false,
    -- set scope for environment and request variables
    -- possible values: b = buffer, g = global
    environment_scope = "b",
  },
}
```

### split_direction

Split direction.

Possible values:

- `vertical`
- `horizontal`

Default: `vertical`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    split_direction = "vertical",
  },
}
```

### default_view

Default view.

Possible values:

- `body`
- `headers`
- `headers_body`
- `script_output`

Default: `body`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    default_view = "body",
  },
}
```

### default_env

Default environment.

See: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files

Possible values:

- `[any string]`

Default: `dev`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    default_env = "dev",
  },
}
```

### debug

Enable debug mode.

Possible values:

- `true`
- `false`

Default: `false`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    debug = false,
  },
}
```

### contenttypes

Filetypes, formatters and path resolvers are defined for each content-type in an hash array

Default:

```lua
contenttypes = {
  ["application/json"] = {
    ft = "json",
    formatter = { "jq", "." },
    pathresolver = require("kulala.parser.jsonpath").parse,
  },
  ["application/xml"] = {
    ft = "xml",
    formatter = { "xmllint", "--format", "-" },
    pathresolver = { "xmllint", "--xpath", "{{path}}", "-" },
  },
  ["text/html"] = {
    ft = "html",
    formatter = { "xmllint", "--format", "--html", "-" },
    pathresolver = {},
  },
}
```

#### contenttypes.ft

Default filetype for the given content type.

Possible values:

Any filetype (`:help filetype`) neovim supports.

Default:

```lua
contenttypes = {
  ["application/json"] = {
    ft = "json",
  },
  ["application/xml"] = {
    ft = "xml",
  },
  ["text/html"] = {
    ft = "html",
  },
```

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    contenttypes = {
      ["text/xml"] = {
        ft = "xml",
      },
    },
  },
}
```

#### contenttypes.formatter

Formatters take the response body and produce a beautified / more human readable output.

Possible values:

- You can define a commandline which processes the body.
  The body will be piped as stdin and the output will be used as the formatted body.
- You can define a lua function `formatted_body = function(body)` which returns the formatted body.

Default:

```lua
contenttypes = {
  ["application/json"] = {
    formatter = { "jq", "." },
  },
  ["application/xml"] = {
    formatter = { "xmllint", "--format", "-" },
  },
  ["text/html"] = {
    formatter = { "xmllint", "--format", "--html", "-" },
  },
}
```

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    contenttypes = {
      ["text/plain"] = {
        formatter = function(body)
          return body:lower()
        end,
      },
    },
  },
}
```

#### contenttypes.pathresolver

You can use Request Variables to read values from requests / responses.
To access a specific value inside a body Kulala gives you the possibility to define a path for it.
This is normally JSONPath for JSON or XPath for XML but can be individually defined for any content type.

Possible values:

- You can use an external program which receives the full body as stdin and has to return the selected value in stdout.
  The placeholder `{{path}}` can be used in any string of this defintion and will be replaced by the actual path (after `body.`).
- Alternative you can give a lua function of `value = function(body, path)`.

Default:

Kulala has implemented a simple JSONPath parser which supports object traversal including array index access.
For full JSONPath support you need to use an external program like `jsonpath-cli` or `jp`.

```lua
contenttypes = {
  ["application/json"] = {
    pathresolver = require("kulala.parser.jsonpath").parse,
  },
  ["application/xml"] = {
    pathresolver = { "xmllint", "--xpath", "{{path}}", "-" },
  },
  ["text/html"] = {
    pathresolver = nil,
  },
}
```

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    contenttypes = {
      ["text/xml"] = {
        pathresolver = { "xmllint", "--xpath", "{{path}}", "-" },
      },
    },
  },
}
```

### show_icons

Can be used to show loading, done and error icons in inlay hints.

Possible values:

- `"on_request"`
- `"above_request"`
- `"below_request"`
- `nil` (to disable inlay hints)

If `"above_request"` or `"below_request"` is used,
the icons will be shown above or below the request line.

Make sure to have a line above or below the request line to show the icons.

Default: `"on_request"`.

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
{
  "mistweaverco/kulala.nvim",
  opts = {
    icons = {
      inlay = {
        loading = "⏳",
        done = "✅"
        error = "❌",
      },
      lualine = "🐼",
    },
  },
}
```

### additional_curl_options

Additional cURL options.

Possible values:

- `[table of strings]`

Default: `{}`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    additional_curl_options = { "--insecure", "-A", "Mozilla/5.0" },
  },
}
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
  "# @name scratchpad",
  "POST https://httpbin.org/post HTTP/1.1",
  "accept: application/json",
  "content-type: application/json",
  "",
  "{",
  '  "foo": "bar"',
  "}",
}
```

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    scratchpad_default_contents = {
      "@AUTH_USERNAME=my_username",
      "",
      "# @name scratchpad_special_name",
      "POST https://httpbin.org/post HTTP/1.1",
      "accept: application/json",
      "content-type: application/json",
      "",
      "{",
      '  "baz": "qux"',
      "}",
    },
  },
}
```

### winbar

Enable winbar for result buffer

Possible values:

- `true`
- `false`

Default: `false`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    winbar = false,
  },
}
```

### vscode_rest_client_environmentvars

If enabled, Kulala searches for `.vscode/settings.json` or `*.code-workspace` files in the current directory and its parents to read the `rest-client.environmentVariables` definitions (`$shared` will be treated as `_base`).

If `http-client.env.json` is also present, it will be merged (and overwrites variables from VSCode).

Possible values:

- `true`
- `false`

Default: `false`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    vscode_rest_client_environmentvars = true,
  },
}
```
### environment_scope

While using request variables the results will be stored for later use.
As usual variables they are file relevant and should be stored in the buffer.
If you want to share the variables between buffers you can use the global scope.

Possible values:

- `"b"` (buffer)
- `"g"` (global)

Default: `"b"`

Example:

```lua
{
"mistweaverco/kulala.nvim",
  opts = {
    environment_scope = "b",
  },
}
```
