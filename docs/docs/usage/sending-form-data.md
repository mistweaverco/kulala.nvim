# Sending Form Data

You can send form data in Kulala by
using the `application/x-www-form-urlencoded` content type.

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

## Sending multipart form data

You can send multipart form data in Kulala by
using the `multipart/form-data` content type.

```http title="multipart.http"
POST https://httpbin.org/post HTTP/1.1
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary{{$timestamp}}

------WebKitFormBoundary{{$timestamp}}
Content-Disposition: form-data; name="logo"; filename="logo.png"
Content-Type: image/jpeg

< /home/giraffe/Pictures/logo.png

------WebKitFormBoundary{{$timestamp}}
Content-Disposition: form-data; name="x"

0
------WebKitFormBoundary{{$timestamp}}
Content-Disposition: form-data; name="y"

1.4333333333333333
------WebKitFormBoundary{{$timestamp}}
Content-Disposition: form-data; name="w"

514.5666666666667
------WebKitFormBoundary{{$timestamp}}
Content-Disposition: form-data; name="h"

514.5666666666667
------WebKitFormBoundary{{$timestamp}}--
```
