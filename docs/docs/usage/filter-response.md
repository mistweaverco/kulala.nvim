# Filter response with JQ

## With `# @jq` directive

You can use `# @jq` directive to filter the response JSON.

```http
# @jq { "username": .username, "password": .password }
POST https://echo.getkulala.net/post HTTP/1.1
Content-Type: application/json

{
  "username": "{{USERNAME}}",
  "password": "{{PASSWORD}}",
}
```

## Manually in the response buffer

Use `F` to toggle the JQ filter in the response buffer.

Enter the query string after `JQ Filter:` and press `Enter` to apply the filter.
