# Magic Variables

There is a predefined set of magic variables that you can use in your HTTP requests.

They all start with a `$` sign.

- `{{$uuid}}` - Generates a random UUID.
- `{{$timestamp}}` - Generates a timestamp.
- `{{$date}}` - Generates a date (YYYY-MM-DD).
- `{{$randomInt}}` - Generates a random integer (between 0 and 9999999).

To test this feature, create a file with the `.http` extension and write your HTTP requests in it.

```http title="magic-variables.http"

POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json

{
  "uuid": "{{$uuid}}",
  "timestamp": "{{$timestamp}}",
  "date": "{{$date}}",
  "randomInt": "{{$randomInt}}",
}

###
```
