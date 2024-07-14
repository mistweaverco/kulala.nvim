# Dynamically setting environment variables based on response JSON

Create a file with the `.http` extension and write your HTTP requests in it.

```http title="examples.http"

POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json
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
content-type: application/json
accept: application/json
authorization: Bearer {{AUTH_TOKEN}}

{
  "success": true,
  "username": "{{AUTH_USERNAME}}"
}

###
POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json
# Setting the environment variables to be used in the next request.
# Only dot notation is supported for JSON objects.
# If you need more fancy stuff you can use a script or jq command.
# See the example below.
# @env-json-key AUTH_TOKEN json.token
# @env-json-key AUTH_USERNAME json.username

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

```
