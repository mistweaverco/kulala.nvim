# Configuration Options

Kulala can be configured with the following options.

### Full example

Here is a full example of setting up
the Kulala plugin with the available `opts`:

```lua title="kulala.lua"
{
  -- cURL path
  -- if you have curl installed in a non-standard path,
  -- you can specify it here
  curl_path = "curl",
  -- additional cURL options
  -- see: https://curl.se/docs/manpage.html
  additional_curl_options = {},
  -- gRPCurl path, get from https://github.com/fullstorydev/grpcurl
  grpcurl_path = "grpcurl",

  -- set scope for environment and request variables
  -- possible values: b = buffer, g = global
  environment_scope = "b",
  -- dev, test, prod, can be anything
  -- see: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
  default_env = "dev",
  -- enable reading vscode rest client environment variables
  vscode_rest_client_environmentvars = false,

  -- default timeout for the request, set to nil to disable
  request_timeout = nil,
  -- disable the vim.print output of the scripts
  -- they will be still written to disk, but not printed immediately
  disable_script_print_output = false,

  -- certificates
  certificates = {},
  -- Specify how to escape query parameters
  -- possible values: always, skipencoded = keep %xx as is
  urlencode = "always",

  -- default formatters/pathresolver for different content types
  contenttypes = {
    ["application/json"] = {
      ft = "json",
      formatter = vim.fn.executable("jq") == 1 and { "jq", "." },
      pathresolver = function(...)
        return require("kulala.parser.jsonpath").parse(...)
      end,
    },
    ["application/xml"] = {
      ft = "xml",
      formatter = vim.fn.executable("xmllint") == 1 and { "xmllint", "--format", "-" },
      pathresolver = vim.fn.executable("xmllint") == 1 and { "xmllint", "--xpath", "{{path}}", "-" },
    },
    ["text/html"] = {
      ft = "html",
      formatter = vim.fn.executable("xmllint") == 1 and { "xmllint", "--format", "--html", "-" },
      pathresolver = nil,
    },
  },

  -- enable/disable debug mode
  debug = false,

  ui = {
    -- display mode: possible values: "split", "float"
    display_mode = "split",
    -- split direction: possible values: "vertical", "horizontal"
    split_direction = "vertical",
    -- default view: "body" or "headers" or "headers_body" or "verbose" or fun(response: Response)
    default_view = "body",
    -- enable winbar
    winbar = true,
    -- Specify the panes to be displayed by default
    -- Current available pane contains { "body", "headers", "headers_body", "script_output", "stats", "verbose" },
    default_winbar_panes = { "body", "headers", "headers_body", "verbose" },
    -- enable/disable variable info text
    -- this will show the variable name and value as float
    -- possible values: false, "float"
    show_variable_info_text = false,
    -- icons position: "signcolumn"|"on_request"|"above_request"|"below_request" or nil to disable
    show_icons = "on_request",
    -- default icons
    icons = {
      inlay = {
        loading = "⏳",
        done = "✅",
        error = "❌",
      },
      lualine = "🐼",
      textHighlight = "WarningMsg", -- highlight group for request elapsed time
      lineHighlight = "Normal", -- highlight group for icons line highlight
    },
    -- enable/disable request summary in the output window
    show_request_summary = true,
    summaryTextHighlight = "Special",

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
  },

  -- set to true to enable default keymaps (check docs or {plugins_path}/kulala.nvim/lua/kulala/config/keymaps.lua for details)
  -- or override default keymaps as shown in the example below.
  ---@type boolean|table
  global_keymaps = false,
  --[[
    {
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
  ]]

  -- Kulala UI keymaps, override with custom keymaps as required (check docs or {plugins_path}/kulala.nvim/lua/kulala/config/keymaps.lua for details)
  ---@type boolean|table
  kulala_keymaps = true,
  --[[
    {
      ["Show headers"] = { "H", function() require("kulala.ui").show_headers() end, },
      ["Show verbose"] = false
    }
  ]]
}
```

### curl_path

cURL path.

If you have `curl` installed in a non-standard path, you can specify it here.

Default: `curl`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    curl_path = "/home/bonobo/.local/bin/curl",
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

### grpcurl_path

gRPCurl path.

If you have `grpcurl` installed in a non-standard path, you can specify it here.
You can get it at [gRPCurl](https://github.com/fullstorydev/grpcurl)

Default: `grpcurl`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    grpcurl_path = "/home/bonobo/.local/bin/grpcurl",
  },
}
```

### environment_scope

While using request variables the results will be stored for later use.
As usual variables they're file relevant and should be stored in the buffer.
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

### default_env

Default environment.

See: [Environment files][see-env-files].

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

### vscode_rest_client_environmentvars

If enabled, Kulala searches for
`.vscode/settings.json` or `*.code-workspace`
files in the current directory and
its parents to read the `rest-client.environmentVariables` definitions.

If `http-client.env.json` is also present,
it'll be merged (and overwrites variables from VSCode).

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

### request_timeout

Set request timeout period.

Possible values:

- `nil`
- `[number]` in ms

Default: `nil`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    request_timeout = 5000,
  },
}
```

### disable_script_print_output

Disable the vim.print output of the scripts as they are executed.
The output will be still written to disk, but not printed immediately.

Possible values:

- `true|false`

Default: `false`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    disable_script_print_output = true,
  },
}
```

### certificates

A hash array of certificates to be used for requests.

The key is the hostname and optional the port. 
If no port is given, the certificate will be used for all ports where no dedicated one is defined.

Each certificate definition needs 

- `cert` the path to the certificate file
- `key` the path to the key files

Example:

```lua
{
"mistweaverco/kulala.nvim",
  opts = {
    certificates = {
      ["localhost"] = {
        cert = vim.fn.stdpath("config") .. "/certs/localhost.crt",
        key = vim.fn.stdpath("config") .. "/certs/localhost.key",
      },
      ["www.somewhere.com:8443"] = {
        cert = "/home/userx/certs/somewhere.crt",
        key = "/home/userx/certs/somewhere.key",
      },
    },
  },
}
```

Hostnames with prefix `*.` will be used as wildcard certificates for the host itself and all subdomains.

`*.company.com` will match

- `company.com`
- `www.company.com`
- `api.company.com`
- `sub.api.company.com`
- etc.

### urlencode

Specify how to escape query parameters.

Possible values:

- `always`
- `skipencoded` = keep already encoded `%xx` as is

Default: `always`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    urlencode = "skipencoded",
  },
}
```

### contenttypes

Filetypes, formatters and path resolvers are
defined for each content-type in an hash array.

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

Formatters take the response body and
produce a beautified / more human readable output.

Possible values:

- You can define a commandline which processes the body.
  The body will be piped as stdin and
  the output will be used as the formatted body.
- You can define a lua function `formatted_body = function(body)`
  which returns the formatted body.

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
To access a specific value inside a body Kulala gives
you the possibility to define a path for it.

This is normally JSONPath for JSON or XPath for XML,
but can be individually defined for any content type.

Possible values:

- You can use an external program which receives the
  full body as stdin and has to return the selected value in stdout.
  The placeholder `{{path}}` can be used in any string of
  this definition and will be replaced by the actual path (after `body.`).
- Alternative you can give a lua function of `value = function(body, path)`.

Default:

Kulala has implemented a basic JSONPath parser which
supports object traversal including array index access.

For full JSONPath support you need to use an
external program like `jsonpath-cli` or `jp`.

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

## UI Options

### ui.display_mode

The display mode.

Can be either `split` or `float`.

Default: `split`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    ui = {
      display_mode = "float",
    }
  },
}
```

### ui.split_direction

Split direction.

Only used when `ui.display_mode` is set to `split`.

Possible values:

- `vertical`
- `horizontal`

Default: `vertical`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    ui = {
      split_direction = "vertical",
    },
  },
}
```

### ui.default_view

Default view.

Possible values:

- `body`
- `headers`
- `headers_body`
- `verbose`
- `script_output`
- `stats`
- `function(response) ... end`

Default: `body`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    ui = {
      default_view = "body",
    },
  },
}
```

Setting the default view to a function allows you to define a custom view handler, which will be called with the response object and will override default views.
The response object has the following properties:

```lua
  ---@class Response
  ---@field id number
  ---@field url string
  ---@field method string
  ---@field status number
  ---@field duration number
  ---@field time string
  ---@field body string
  ---@field headers string
  ---@field errors string
  ---@field stats string
  ---@field script_pre_output string
  ---@field script_post_output string
  ---@field buf number
  ---@field buf_name string
  ---@field line number
  local response = {}
```

### ui.winbar

Enable winbar for result buffer

Possible values:

- `true`
- `false`

Default: `true`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    ui = {
      winbar = true,
    },
  },
}
```

### ui.default_winbar_panes

Default visible winbar panes

Possible values:

- `body`
- `headers`
- `headers_body`
- `verbose`
- `script_output`
- `stats`

Default: `body`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    ui = {
      default_winbar_panes = { "body", "headers", "headers_body", "verbose" },
    },
  },
}
```

### ui.show_variable_info_text

Enable/disable variable info text.

Possible values:

- `false` = disable variable info text
- `"float"` = show the variable name and value as float

Default: `always`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    ui = {
      show_variable_info_text = false,
    },
  },
}
```

### ui.show_icons

Can be used to show loading, done and error icons in inlay hints or signcolumn

Possible values:

- `"singcolumn"`
- `"on_request"`
- `"above_request"`
- `"below_request"`
- `nil` (to disable inlay hints)

If `"above_request"` or `"below_request"` is used,
the icons will be shown above or below the request line.

Default: `"on_request"`.

### ui.icons

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
  textHighlight = "WarningMsg",
  lineHighlight = "Normal",
}
```

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    ui = {
      icons = {
        inlay = {
          loading = "⏳",
          done = "✅"
          error = "❌",
        },
        lualine = "🐼",
        textHighlight = "WarningMsg",
        lineHighlight = "Normal",
      },
    },
  },
}
```

### ui.show_request_summary

Enable/disable request summary in the output window.

Possible values:

- `true`
- `false`

Default: `true`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  opts = {
    ui = {
      show_request_summary = false,
    },
  },
}
```

### ui.summaryTextHighlight

Highlight group for the request summary in the output window.

Default: `Special`

### ui.scratchpad_default_contents

Scratchpad default contents.

The contents of the scratchpad when it's opened
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
    ui = {
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
  },
}
```

## Keymaps

### global_keymaps

Set to `true` to enable default keymaps.

Check the [keymaps documentation](keymaps.md) for details.

Default: `false`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  global_keymaps = true,
}
```

### kulala_keymaps

Set to `true` to enable default keymaps for the Kulala UI.

Check the [keymaps documentation](keymaps.md) for details.

Default: `true`

Example:

```lua
{
  "mistweaverco/kulala.nvim",
  kulala_keymaps = false,
}
```

[see-env-files]: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
