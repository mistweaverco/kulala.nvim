# HTTP File Specification

- The .http file syntax.
- How to create an .http file.
- How to send a request from an .http file.


### Requests

The format for an HTTP request is `HTTPMethod` `URL` `HTTPVersion`,
all on one line, where:

- `HTTPMethod` is the HTTP method to use, for example:
  - `OPTIONS`
  - `GET`
  - `HEAD`
  - `POST`
  - `PUT`
  - `PATCH`
  - `DELETE`
  - `TRACE`
  - `CONNECT`
- `URL` is the URL to send the request to.
  The URL can include query string parameters.
  The URL doesn't have to point to a local web project.
  It can point to any URL that Visual Studio can access.
- `HTTPVersion` is optional and specifies the HTTP version that should be used,
  that's, `HTTP/1.1`, `HTTP/2`, or `HTTP/3`.

A file can contain multiple requests by using lines with `###` as delimiters.
The following example showing three requests in a file illustrates this syntax:

```http
GET https://localhost:7220/weatherforecast

###

GET https://localhost:7220/weatherforecast?date=2023-05-11&location=98006

###

GET https://localhost:7220/weatherforecast HTTP/3

###
```
### Request headers

To add one or more headers,
add each header on its own line immediately after the request line.
Don't include any blank lines between the request line and
the first header or between subsequent header lines.
The format is `header-name`: `value`, as shown in the following examples:

```http
GET https://localhost:7220/weatherforecast
Date: Wed, 27 Apr 2023 07:28:00 GMT

###

GET https://localhost:7220/weatherforecast
Cache-control: max-age=604800
Age: 100

###
```

> Don't add any secrets to a source code repository.

### Request body

Add the request body after a blank line, as shown in the following example:

```http
POST https://localhost:7220/weatherforecast
Content-Type: application/json
Accept-Language: en-US,en;q=0.5

{
    "date": "2023-05-10",
    "temperatureC": 30,
    "summary": "Warm"
}

###
```

### Comments

Lines that start with either `#` are comments.
These lines are ignored when kulala sends HTTP requests.

### Variables

A line that starts with `@` defines a variable
by using the syntax `@VariableName=Value`.

Variables can be referenced in requests that are defined later in the file.
They're referenced by wrapping their names in double curly braces,
`{{` and `}}`.

The following example shows two variables defined and used in a request:

```http
@hostname=localhost
@port=44320

GET https://{{hostname}}:{{port}}/weatherforecast
```

Variables can be defined using values of
other variables that were defined earlier in the file.

The following example uses one variable in the request
instead of the two shown in the preceding example:

```http
@hostname=localhost
@port=44320
@host={{hostname}}:{{port}}

GET https://{{host}}/api/search/tool
```
