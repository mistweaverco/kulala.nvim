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

### content types

Filetypes, formatters and path resolvers are defined for each content-type in an hash array

Default:

```lua
content_types = {
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

#### filetypes

Default filetype for the given content type.

Possible values:

Any filetype (`:help filetype`) neovim supports.

Default:

```lua
content_types = {
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
require("kulala").setup({
  content_types = {
    ["text/xml"] = {
      ft = "xml",
    },
  },
})
```

#### formatters

Formatters take the response body and produce a beautified / more human readable output.

Possible values:

- You can define a commandline which processes the body. 
  The body will be piped as stdin and the output will be used as the formatted body.
- You can define a lua function `formatted_body = function(body)` which returns the formatted body.

Default:

```lua
content_types = {
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
require("kulala").setup({
  content_types = {
    ["text/plain"] = {
      formatter = function(body)
        return body:lower()
      end,
    },
  },
})
```

#### path resolvers

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
content_types = {
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
require("kulala").setup({
  content_types = {
    ["text/xml"] = {
      pathresolver = { "xmllint", "--xpath", "{{path}}", "-" },
    },
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

