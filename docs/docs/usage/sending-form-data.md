# Sending Form Data

You can send form data in Kulala by using the `application/x-www-form-urlencoded` content type.

Create a file with the `.http` extension and write your HTTP requests in it.

```http title="examples.http"
@name=John
@age=30

POST https://httpbin.org/post HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Accept: application/json

name={{name}}&
age={{age}}
```

