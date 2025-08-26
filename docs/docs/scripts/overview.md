# Scripts overview

You can use scripts to automate tasks in the editor.
Scripts can be either written in `Lua` or in `JavaScript` and executed via `node`.

:::warning

[Node.js](https://nodejs.org) must be installed on your system to run `Javascript` scripts.

:::

### Current working directory

The current working directory for scripts is:

- the directory of the current HTTP file for inline scripts
- the directory of the external script file for external scripts

Given the following folder structure:

```plaintext
.
├── http
│   └── example.http
│   └── example.js
│   └── example.lua
└── scripts
    └── my-script.js
    └── my-script.lua
```

The current working directory for `my-script.js` is the `scripts` directory,
whereas the current working directory for `example.js` is the `http` directory.

All inline scripts are executed in the
current working directory of the HTTP file,
which is the `http` directory in this case.

By default, the `NODE_PATH` environment variable is resolved to the first `node_modules` directory found upwards from the script working directory.

You can provide a custom `node_path_resolver` function in your configuration, by setting the `scripts.node_path_resolver` option.

```lua
{
  opts = {
    scripts = {
      node_path_resolver = nil, ---@type fun(http_file_dir: string, script_file_dir: string, script_data: ScriptData): string|nil
    }
  }
}

```
### Lua scripts

Please read [Lua scripting](./lua-scripts) for more information.

:::warning

Mixing inline Lua scripts with JavaScript scripts in the same request is not supported.  Script language is determined by the first script in the pre-request or post-request section.

:::

### LSP support for auto completion

For external scripts, you can use the `kulala` LSP to get auto completion for the `client`, `request`, `response`, `test` and `assert` objects.

To do this, add `javascript`/`lua` to `lsp.filetypes` in your [Configuration options](../getting-started/configuration-options.mdx):

```lua
{
  opts = {
    lsp = {
      filetypes = { "http", "rest", "json", "yaml", "bruno", "javascript" }
    },
  },
}
```

### Using node modules

You can use any Node.js module in your scripts.

If you have a folder structure like this:

```plaintext
.
├── http
│   └── example.http
└── scripts
    └── my-script.js
```

You can use the `require` function to import modules in `my-script.js`:

```javascript
const moment = require("moment");
```

as long as the module is installed in the
same directory as the script, or globally.

The current working directory for `my-script.js` is the `scripts` directory.

So want to write a file in the `http` directory, you can use a relative path:

```javascript
const fs = require("fs");
fs.writeFileSync("../http/my-file.txt", "Hello, world!");
```
## Pre-request

```http title="./pre-request-example.http"
### REQUEST_ONE
< {%
  var crypto = require('crypto');
  var fs = require('fs');
  var TOKEN = fs.readFileSync('TOKEN.txt', 'utf8').trim();
  request.variables.set('GORILLA', TOKEN);
  request.variables.set('PASSWORD', crypto.randomBytes(16).toString('hex'));
%}
< ./pre-request.js
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json
Authorization: Bearer Foo:bar

{
  "token": "{{GORILLA}}",
  "password": "{{PASSWORD}}",
  "deep": {
    "nested": [
      {
        "key": "foo"
      },
      {
        "key": "{{BONOBO}}"
      }
    ]
  }
}

###

### REQUEST_TWO
POST https://httpbin.org/post HTTP/1.1
accept: application/json
content-type: application/json

{
  "token": "{{REQUEST_ONE.response.body.$.json.token}}",
  "nested": "{{REQUEST_ONE.response.body.$.json.deep.nested[1].key}}",
  "gorilla": "{{GORILLA}}"
}
```

:::tip

Variables set via `request.variables.set` are
only available in the current request.

:::

```javascript title="./pre-request.js"
client.global.set("BONOBO", "bar");
```

:::tip

Variables set via `client.global.set` are available in all requests and
persist between neovim restarts.

To clear a global variable,
run `lua require('kulala').scripts_clear_global('BONOBO')`.

See: [scripts_clear_global](../usage/public-methods#scripts_clear_global).

:::

```text title="./TOKEN.txt"
THIS_IS_SOME_TOKEN_VALUE_123
```

## Post-request

```http title="./post-request-example.http"
### REQUEST_ONE_
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json
Authorization: Bearer Foo:bar

{
  "token": "SOME_TOKEN",
  "deep": {
    "nested": [
      {
        "key": "foo"
      }
    ]
  }
}

> {%
  var fs = require('fs');
  fs.writeFileSync('TOKEN.txt', response.body.json.token);
  client.global.set('GORILLA_TOKEN', response.body.json.token);
%}

###

### REQUEST_TWO_2_
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "gorilla": "{{GORILLA_TOKEN}}"
}

> ./post-request.js

###

### REQUEST_THREE
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "date_header_from_request_two": "{{BONOBO}}"
}
```

```javascript title="./post-request.js"
client.global.set("BONOBO", response.headers.valueOf("Date"));
```

## Print Variables

```http title="./pre-request-example.http"
### REQUEST_ONE
< {%
  var crypto = require('crypto');
  var fs = require('fs');
  var TOKEN = fs.readFileSync('TOKEN.txt', 'utf8').trim();
  var PASSWORD = crypto.randomBytes(16).toString('hex');
  request.variables.set('GORILLA', TOKEN);
  request.variables.set('PASSWORD', PASSWORD);
  console.log(TOKEN)
  console.log(PASSWORD)
%}
< ./pre-request.js
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json
Authorization: Bearer Foo:bar

{
  "token": "{{GORILLA}}",
  "password": "{{PASSWORD}}",
  "deep": {
    "nested": [
      {
        "key": "foo"
      },
      {
        "key": "{{BONOBO}}"
      }
    ]
  }
}

> {%
  var token = response.body.json.token
  var fs = require('fs');
  fs.writeFileSync('TOKEN.txt', token);
  client.global.set('GORILLA_TOKEN', token);
  console.log(token)
%}
```

:::tip

If you add `console.log` to script,
the output will be displayed in the `Script Output` panel,
when you have enabled the following configuration.

```lua
opts = {
  default_winbar_panes = { "body", "headers", "headers_body", "script_output" },
}
```

:::
