# Reading File Data

Create a file with the `.http` extension and
write your JSON request in it.

Then, use redirection `<` to specify the file path.
that you want to use in the request.


```http title="file-to-variable.http"
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json

< /home/giraffe/Downloads/test-include.json

```
The content of the `test-include.json` file will
be used as the request body.

```json title="test-include.json"
{
  "foo": "bar",
  "baz": {
    "qux": "quux"
  }
}
```
