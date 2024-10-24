# File to variable

You can use the `@file-to-variable` directive to
read the content of a file and assign it to a variable.

Create a file with the `.http` extension and
write your JSON request in it.

Then, use the `@file-to-variable` directive to specify the variable name
that you want to use in the request.

The second argument is the path to the file.


```http title="file-to-variable.http"
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Accept: application/json
# @file-to-variable TEST_INCLUDE ./test-include.json

{
  "test-include": {{TEST_INCLUDE}}
}

```
The `TEST_INCLUDE` variable will be replaced with
the content of the `test-include.json` file.

```json title="test-include.json"
{
  "foo": "bar",
  "baz": {
    "qux": "quux"
  }
}
```
