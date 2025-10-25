# HTTP File Specification

- The .http file syntax.
- How to create an .http file.
- How to send a request from an .http file.


### Requests

Kulala supports `absolute`, `origin` and `asterisk path` formats for HTTP request.

`Absolute` format: `HTTPMethod` `URL` `HTTPVersion`: 
```http
GET https://weather.com:7220/weatherforecast?city=New York&day=2025-05-07
```

 `Origin` format: `HTTPMethod` `URL`:

Single line
```http
GET /api/get?id=123&value=some thing
Host: example.com
```

Multiline
```http
GET http://example.com:8080
 /api
 /html
 /get
 ?id=123
 &value=some "longer" content
```

 `Asterisk` format: `HTTPMethod` `URL`:
```http
OPTIONS * HTTP/1.1
Host: http://example.com:8080
```

- `HTTPMethod` specifies HTTP method to use, it is optional (default is `GET`). For example:
  - `OPTIONS`
  - `GET`
  - `HEAD`
  - `POST`
  - `PUT`
  - `PATCH`
  - `DELETE`
  - `TRACE`
  - `CONNECT`
  - `GRAPHQL`
  - `GRPC`
  - `WS`

- `Scheme` is the scheme to use, it is optional (default is `http`). For example:
  - `http`
  - `https`
  - `ws`
  - `wss`

- `URL` is the URL to send the request to.
  The URL can include query string parameters, which are automatically url-encoded.
  The URL doesn't have to point to a local web project and can point to any URL.
  Numeric IPv4 `http://127.0.0.1` and IPv6 `http://[::1]` addresses are supported.

- `HTTPVersion` is optional and specifies the HTTP version that should be used,
  that's, `HTTP/1.1`, `HTTP/2`, or `HTTP/3`.

A file can contain multiple requests by using lines with `###` as delimiters.  
You can provide a name for the request, for example `### Auth request`, to reference it in scripts and other requests.
The following example showing three requests in a file illustrates this syntax:

```http
GET https://localhost:7220/weatherforecast

### Weather forecast for Seattle

GET https://localhost:7220/weatherforecast?date=2023-05-11&location=98006

### Weather forecast 

GET /weatherforecast HTTP/3
Host: localhost:7220

###
```
### Request headers

To add one or more headers, add each header on its own line immediately after the request line.
Don't include any blank lines between the request line and the first header or between subsequent header lines.
The format is `header-name`: `value`, as shown in the following examples:

The `Cookie` headers will set the cookies for the request.

```http
GET https://localhost:7220/weatherforecast
Date: Wed, 27 Apr 2023 07:28:00 GMT

##`### Auth request` to reference it in scripts and other requests.

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
Cookie: _ga=GA1.2.1903065019.1615319519

{
    "date": "2023-05-10",
    "temperatureC": 30,
    "summary": "Warm"
}

###
```

### Comments

Lines that start with either `#` or `//` are comments.
These lines are ignored when Kulala sends HTTP requests.

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
