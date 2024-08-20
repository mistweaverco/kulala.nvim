# Scripts

You can use scripts to automate tasks in the editor.
Scripts are written in JavaScript and executed via `node`.

:::warning

Node.js must be installed on your system to run scripts.

:::

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
run [`lua require('kulala').scripts_clear_global('BONOBO')`](configuration-options#scripts_clear_global).

:::

