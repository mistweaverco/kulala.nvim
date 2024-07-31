# Dynamically setting environment variables based on headers

You can set environment variables based on the headers of a HTTP request.

Create a file with the `.http` extension and write your HTTP requests in it.

## Simple example

The headers of the first request can be obtained and used in the second request.
The keys of the headers are all lowercase,
even if they are written in uppercase or mixed-case in the request.

In this example, the `content-type` and `date` headers are received in the first request.
The headers received are actually `Content-Type` and `Date`, but they are converted to lowercase.

```http title="simple.http"
POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json
# @env-header-key HEADER_CONTENT_TYPE content-type
# @env-header-key HEADER_DATE date

{
  "type": "very-simple"
}

###

POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json

{
  "success": true,
  "previous_request_header_content_type": "{{HEADER_CONTENT_TYPE}}",
  "previous_request_header_date": "{{HEADER_DATE}}"
}
```
