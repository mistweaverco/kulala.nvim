# Using Environment Variables

Create a file with the `.http` extension and write your HTTP requests in it.

```http title="examples.http"

POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json

{
  "username": "{{AUTH_USERNAME}}",
  "password": "{{AUTH_PASSWORD}}",
}

```
