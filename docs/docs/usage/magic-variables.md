# Magic Variables

There is a predefined set of magic variables that
you can use in your HTTP requests.

They all start with a `$` sign.

A Unique User Identifier (UUID) is a 128-bit number used to
identify information in computer systems.

- `{{$uuid}}` - Generates a UUID.
- `{{$timestamp}}` - Generates a timestamp.
- `{{$date}}` - Generates a date (yyyy-mm-dd).
- `{{$randomInt}}` - Generates a random integer (between 0 and 9999999).

To test this feature,
create a file with the `.http` extension and write your HTTP requests in it.

```http title="magic-variables.http"
POST https://echo.getkulala.net/post HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "uuid": "{{$uuid}}",
  "timestamp": "{{$timestamp}}",
  "date": "{{$date}}",
  "randomInt": "{{$randomInt}}"
}
```
