# Dynamically setting environment variables based on response JSON

You can set environment variables based on the response JSON of a HTTP request.

Create a file with the `.http` extension and write your HTTP requests in it.

## With built-in parser

If the response is a *simple* JSON object,
you can set environment variables using the `@env-json-key` directive.

```http title="with-builtin-parser.http"
# Setting the environment variables to be used in the next request.
# @name REQUEST_ONE
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "username": "{{USERNAME}}",
  "password": "{{PASSWORD}}",
  "token": "foobar"
}

###

POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json
Authorization: Bearer {{REQUEST_ONE.response.body.$.json.token}}

{
  "success": true,
  "username": "{{REQUEST_ONE.response.body.$.json.username}}"
}
```

## With external command

If the response is a *complex* JSON object,
you can use the `@env-stdin-cmd` directive to
set environment variables using an external command (e.g., `jq`).

```http title="with-external-jq.http"
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json
# Setting the environment variables to be used in the next request.
# Any external command can be used to set the environment variables.
# The command should output the environment variable as string.
# @env-stdin-cmd AUTH_TOKEN jq -rcj .json.token
# @env-stdin-cmd AUTH_USERNAME jq -rcj .json.username

{
  "username": "{{USERNAME}}",
  "password": "{{PASSWORD}}",
  "token": "foobar"
}

###

POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json
Authorization: Bearer {{AUTH_TOKEN}}

{
  "success": true,
  "username": "{{AUTH_USERNAME}}"
}
```
