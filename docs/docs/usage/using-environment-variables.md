# Using Environment Variables

You can use environment variables in your HTTP requests.

Create a file with the `.http` extension and write your HTTP requests in it.

```http title="examples.http"
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "username": "{{AUTH_USERNAME}}",
  "password": "{{AUTH_PASSWORD}}",
}
```
