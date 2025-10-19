# Dynamically setting environment variables based on headers

You can set environment variables based on the headers of a HTTP request.

Create a file with the `.http` extension and write your HTTP requests in it.

## Example

The headers of the first request can be obtained and used in the second request.

In this example, the `Content-Type` and `Date` headers are
received in the first request.

```http title="simple.http"
### REQUEST_ONE
POST https://echo.getkulala.net/post HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "type": "very-simple"
}

###

POST https://echo.getkulala.net/post HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "success": true,
  "previous_request_header_content_type": "{{REQUEST_ONE.response.headers['Content-Type']}}",
  "previous_request_header_date": "{{REQUEST_ONE.response.headers.Date}}"
}
```
