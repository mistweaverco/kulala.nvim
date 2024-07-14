# Sending Form Data

Create a file with the `.http` extension and write your HTTP requests in it.

```http title="examples.http"

@name=John
@age=30

POST https://httpbin.org/post HTTP/1.1
content-type: application/x-www-form-urlencoded
accept: application/json

name={{name}}
&age={{age}}

```

