# Request Variables

The definition syntax of request variables is just like a single-line comment,
and follows `# @name REQUEST_NAME` just as metadata.

```http
# @name THIS_IS_AN_EXAMPLE_REQUEST_NAME
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/x-www-form-urlencoded

name=foo&password=bar
```

You can think of request variable as attaching
a name metadata to the underlying request.

This kind of requests can be called with Named Request.

Other requests can use `THIS_IS_AN_EXAMPLE_REQUEST_NAME` as an
identifier to reference the expected part of
the named request or its latest response.

:::warning

If you want to refer the response of a named request,
you need to manually trigger the named request to retrieve its response first.
Otherwise the plain text of
variable reference like
`{{THIS_IS_AN_EXAMPLE_REQUEST_NAME.response.body.$.id}}`
will be sent instead.

:::

The reference syntax of a request variable is a
bit more complex than other kinds of custom variables.

## Request Variable Reference Syntax

The request variable reference syntax follows

```
{{REQUEST_NAME.(response|request).(body|headers).(*|JSONPath|XPath|Header Name)}}`
```

You have two reference part choices of
the `response` or `request`: `body` and `headers`.

For `body` part,
you can use JSONPath and XPath to extract specific property or attribute.

### Special case for cookies

The response cookies can be referenced by
```
{{REQUEST_NAME.response.cookies.CookieName.(value|domain|flag|path|secure|expires)}}`
```

```http
# @name REQUEST_GH
GET https://github.com HTTP/1.1

###

POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "logged_into_gh": "{{REQUEST_GH.response.cookies.logged_in.value}}"
}

```

:::tip

If you don't want Kulala to create a cookie jar for a specific request,
you can add the meta-tag `@no-cookie-jar` to the request.

```http
# @no-cookie-jar
GET https://github.com HTTP/1.1
```

:::

## Example

if a JSON response returns `body` `{"id": "mock"}`,
you can set the JSONPath part to `$.id` to reference the `id`.

For `headers` part, you can specify the header name to extract the header value.

The header name is case-sensitive for `response` part,
and all lower-cased for `request` part.

If the *JSONPath* or *XPath* of `body`,
or *Header Name* of `headers` can't be resolved,
the plain text of variable reference will be sent instead.

And in this case,
diagnostic information will be displayed to help you to inspect this.

Below is a sample of request variable definitions and
references in an http file.

```http
# @name REQUEST_ONE
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "token": "foobar"
}

###

# @name REQUEST_TWO
POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "token": "{{REQUEST_ONE.response.body.$.json.token}}"
}

###

POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "date_header": "{{REQUEST_TWO.response.headers['Date']}}"
}
```
