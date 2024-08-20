# Scripts overview

You can use scripts to automate tasks in the editor.
Scripts are written in JavaScript and executed via `node`.

:::warning

[Node.js](https://nodejs.org) must be installed on your system to run scripts.

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
└── scripts
    └── my-script.js
```

The current working directory for `my-script.js` is the `scripts` directory,
whereas the current working directory for `example.js` is the `http` directory.

All inline scripts are executed in the current working directory of the HTTP file,
which is the `http` directory in this case.

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
const moment = require('moment');
```
as long as the module is installed in the same directory as the script, or globally.

The current working directory for `my-script.js` is the `scripts` directory.

So want to write a file in the `http` directory, you can use a relative path:

```javascript
const fs = require('fs');
fs.writeFileSync('../http/my-file.txt', 'Hello, world!');
```

## Pre-request

```http title="./pre-request-example.http"
# @name REQUEST_ONE
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

# @name REQUEST_TWO
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

Variables set via `request.variables.set` are only available in the current request.

:::

```javascript title="./pre-request.js"
client.global.set("BONOBO", "bar");
```

:::tip

Variables set via `client.global.set` are available in all requests and
persist between neovim restarts.

To clear a global variable,
run [`lua require('kulala').scripts_clear_global('BONOBO')`](../usage/public-methods#scripts_clear_global).

:::

```plaintext title="./TOKEN.txt"
THIS_IS_SOME_TOKEN_VALUE_123
```

## Pre-request

```http title="./pre-request-example.http"
# @name REQUEST_ONE
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

# @name REQUEST_TWO
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

Variables set via `request.variables.set` are only available in the current request.

:::

```javascript title="./pre-request.js"
client.global.set("BONOBO", "bar");
```

:::tip

Variables set via `client.global.set` are available in all requests and
persist between neovim restarts.

To clear a global variable,
run [`lua require('kulala').scripts_clear_global('BONOBO')`](../usage/public-methods#scripts_clear_global).

:::

```text title="./TOKEN.txt"
THIS_IS_SOME_TOKEN_VALUE_123
```
## Post-request

```http title="./post-request-example.http"
# @name REQUEST_ONE
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

# @name REQUEST_TWO
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "gorilla": "{{GORILLA_TOKEN}}"
}

> ./post-request.js

###

# @name REQUEST_THREE
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
