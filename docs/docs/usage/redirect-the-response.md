# Redirect the response

You can redirect the response to a file.


## Do not overwrite file

By using the `>>` operator followed by the file name, the response will be saved to the file.

If the file already exists, a warning will be displayed, and the file will not be overwritten.

To overwrite the file, use the `>>!` operator.


```http title="do-not-overwrite.http"
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "name": "Kulala"
}

>> kulala.json
```

## Overwrite file

To overwrite the file, use the `>>!` operator.

```http title="overwrite.http"
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "name": "Kulala"
}

>>! kulala.json
```
