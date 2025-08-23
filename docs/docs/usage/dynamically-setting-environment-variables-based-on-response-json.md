# Dynamically setting environment variables based on response JSON

You can set environment variables based on the response JSON of a HTTP request.

Create a file with the `.http` extension and write your HTTP requests in it.

## With built-in parser

If the response is a *uncomplicated* JSON object,
you can set environment variables using
the [request variables](request-variables) feature.

```http title="with-builtin-parser.http"
# Setting the environment variables to be used in the next request.
### REQUEST_ONE
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

If the response is a *complex* JSON object, you can use the `@env-stdin-cmd` directive to
set environment variables using an external command (e.g., `jq`).

Response is passed to the command via standard input (stdin) and the result is assigned to a variable,
which can be used in subsequent requests.

JSON Web Tokens (JWT) are a common example where the response JSON is complex.

In this example `jq` is used to extract the `ctx` string from a JWT token.

```http title="with-external-jq.http"
# Setting the environment variables to be used in the next request.
# Any external command can be used to set the environment variables.
# The command should output the environment variable as string.
# @env-stdin-cmd JWT_CONTEXT jq -r '.json.token | gsub("-";"+") | gsub("_";"/") | split(".") | .[1] | @base64d | fromjson | .ctx'
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0eXBlIjoiZ29yaWxsYSIsIm5hbWUiOiJHb3JpbGxhIE1vZSIsImN0eCI6IlNvbWUgY29udGV4dCIsIndlYnNpdGUiOiJodHRwczovL2dvcmlsbGEubW9lIn0.YmEG9bOo1o9opeWnCsfW621A-sB_5WXSBI2FjtvwXlk"
}

###

POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "success": true,
  "context": "{{JWT_CONTEXT}}"
}
```
