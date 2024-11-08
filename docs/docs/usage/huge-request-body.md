# Huge Request Body

If you try to create a request with a large body,

an error might occur due to a shell limitation of arg list size.

To avoid this error, you can use the `@write-body-to-temporary-file`
meta tag in the request section.

This tells Kulala to write the request body to a
temporary file and use the file as the request body.

:::note

For `Content-Type: multipart/form-data` this isn't not necessary,
because Kulala enforces the use of temporary files for this content type.

:::

```http title="huge-request-body.http"

# @write-body-to-temporary-file
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json

{
  "name": "John",
  "age": 30,
  "address": "123 Main St, Springfield, IL 62701",
  "phone": "555-555-5555",
  "email": ""
}
```

In the example above, the request body is written to a temporary file.
