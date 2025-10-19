# Lua Scripts

You can use scripts to automate tasks in the editor.
Using Lua scripts, you can manipulate request and response data, prior and after the request is sent.

By default, all scripts in HTTP files are considered to be `JavaScript`. To indicate Kulala that a script is written in `Lua`,
put `-- lua` at the beginning of the script.

Script context has the following objects and functions available:

- `client` - The client object.
- `request` - The request object.
- `response` - The response object.
- `assert` - The assert object - a collection of assertion functions.

as well as access to Neovim's `_G` global table.

For authentication purposes, you can use Kulala's crypto module with `require("kulala.cmd.crypto")`

### Client

```lua
local client = {
  global = {}, -- global variables persisted between requests
  responses = {}, -- responses of previous requests
  clear_all = function() end, -- clear all global variables
  log = function(msg) end, -- log a message
  test = function(name, fn) end, -- alias for assert.test
  assert = assert, -- alias for assert
}
```

### Request

```lua
---@class Request
---@field metadata { name: string, value: string }[] -- Metadata of the request
---@field environment table<string, string|number> -- The environment and document-variables
---
---@field method string -- The HTTP method of the request
---@field url string -- The URL with variables and dynamic variables replaced
---@field url_raw string -- The raw URL as it appears in the document
---@field request_target string|nil -- The target of the request
---@field http_version string -- The HTTP version of the request
---
---@field headers table<string, string> -- The headers with variables and dynamic variables replaced
---@field headers_raw table<string, string> -- The headers as they appear in the document
---@field headers_display table<string, string> -- The headers with variables and dynamic variables replaced and sanitized
---@field cookie string -- The cookie as it appears in the document
---
---@field body string|nil -- The body with variables and dynamic variables replaced
---@field body_raw string|nil -- The raw body as it appears in the document
---@field body_computed string|nil -- The computed body as sent by curl; with variables and dynamic variables replaced
---@field body_display string|nil -- The body with variables and dynamic variables replaced and sanitized
local request = {
  skip = function() end, -- skip the request (useful in pre-request scripts)
  replay = function() end, -- replay the request (useful in post-request scripts)
  variables = {}, -- request variables, alias for environment (for compatibility with JS scripting)
  iteration = function() end, -- the current count of request replays
}
```

### Response

```lua
---@class Response
---@field id string
---@field name string -- name of the request
---
---@field url string -- request url
---@field method string -- request method
---@field request { headers_tbl: table, body: string } -- request
---
---@field status boolean -- status of the request
---@field code number -- request command exit code
---@field response_code number -- http response code
---
---@field duration number -- duration of the request
---@field time number -- time of the request
---
---@field body string -- body of the response
---@field body_raw string -- body of the response (unaltered)
---@field json table -- json response
---@field filter string|nil -- jq filter if applied
---
---@field headers string -- headers of the response
---@field headers_tbl table -- parsed headers of the response
---
---@field cookies table -- received cookies
---
---@field errors string -- errors of the request
---@field stats table|string -- stats of the request
---
---@field script_pre_output string
---@field script_post_output string
---
---@field assert_output table
---@field assert_status boolean
---
---@field file string -- path of the file of the request
---@field buf number
---@field buf_name string
---@field line number
local response = {}
```

### Assert

```lua
local assert = {
  test = function(name, fn) end, -- define a test suite
  is_true = function(value, message) end, -- check if value is true
  is_false = function(value, message) end, -- check if value is false
  same = function(value, expected, message) end, -- check if value is the same as expected
  has_string = function(value, expected, message) end, -- check if value has the expected string
  response_has = function(key, expected, message) end, -- check if response has the expected key:value (accepts nested keys "key1.key2")
  headers_has = function(key, expected, message) end, -- check if headers has the expected key:value
  body_has = function(expected, message) end, -- check if body has the expected string
  json_has = function(key, expected, message) end, -- check if json has the expected key:value (if response is json; accepts nested keys "key1.key2")
}
```

Please see [Testing and reporting](../usage/testing-and-reporting.md) for more details.

## Pre-request

```http
### REQUEST_ONE

< {%
  -- lua
  client.log("Pre-request script")

  request.environment.Token = "Foo" -- set request local variable
  request.environment.PASSWORD = "Bar" -- set request local variable

  client.global.BONOBO = "baz" -- set global variable

  if not request.environment.Auth == "Foo" then
    request.skip() -- skip the request
  end

%}

< ./pre-request.lua

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

## Post-request

```http
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json
Authorization: Bearer {{TOKEN}}

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
  -- lua
  client.log("Post-request script")

  if response.response_code == 403 then
    request.url_raw = "https://httpbin.org/other_endpoint"
    request.environment.TOKEN = "Bar"
    request.replay() -- replay the request
  end

  client.global.BONOBO = response.json.deep.nested[1].key -- set global variable

  assert(response.response_code == 200, "Response failed")
  assert.json_has("deep.nested.key", { "foo" }, "Check if key is foo")
%}

> ./post-request.lua
```

:::tip

If you want to modify request URL, headers or body, use `request.url_raw`, `request.headers_raw` or `request.body_raw` respectively.

:::

### Changing JSON body of a request

```http
### Change JSON body

< {%
  -- lua
  local json = require("kulala.utils.json")
  local body = json.parse(request.body)

  body.your_var = "whatever"
  request.body_raw = json.encode(body)
%}

POST http://httpbin.org/post HTTP/1.1

{
  "your_var": "original_value"
}
```

### Iterating over results and making requests for each item

```http
### Request_one

POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "results": [
    { "id": 1, "desc": "some_username" },
    { "id": 2, "desc": "another_username" }
  ]
}

### Request_two

< {%
  -- lua
  local response = client.responses["Request_one"].json -- get body of the response decoded as json
  if not response then return end

  local item = response.json.results[request.iteration()]
  if not item then return request.skip() end   -- skip if no more items

  client.log(item)
  request.url_raw = request.environment.url .. "?" .. item.desc
%}

@url = https://httpbin.org/get
GET {{url}}

> {%
  -- lua
  request.replay()
%}
```
