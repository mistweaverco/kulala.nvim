## Usage

Create a file with the `.http` extension and write your HTTP requests in it.

```http filename="examples.http"

@name=John
@age=30

GET https://pokeapi.co/api/v2/pokemon/{{pokemon}} HTTP/1.1
accept: application/json

###

POST https://httpbin.org/post HTTP/1.1
content-type: application/x-www-form-urlencoded
accept: application/json

name={{name}}
&age={{age}}

###

POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json
# @env-stdin-cmd AUTH_TOKEN jq -rcj .json.token
# @env-stdin-cmd AUTH_USERNAME jq -rcj .json.username

{
  "username": "{{USERNAME}}",
  "password": "{{PASSWORD}}",
  "token": "foobar"
}

###

POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json
authorization: Bearer {{AUTH_TOKEN}}

{
  "success": true,
  "username": "{{AUTH_USERNAME}}"
}

###

POST https://httpbin.org/post?grant_type=password&client_id=here_goes_client_id&client_secret=here_goes_client_secret&username=mysfusername&password=mysfpasswordplustoken HTTP/1.1
accept: application/json
```

Place the cursor on any item
in the `examples.http` and
run `:lua require('kulala').run()`.

> Want to see the response headers instead of the response body?

With `require('kulala').toggle_view()` you can switch between the `body` and `headers` view of the last run request.

This persists across restarts.
