# Scripts response reference

These helper functions are available in the response object in scripts.

## response.responseCode

THe HTTP response code.

## response.body

The response body, as a string, or json object if the response is json.

```javascript
client.log(response.body);
```

## response.headers

Returns all response header objects.

Each header object has the following methods:

- `header.valueOf(headerName)` - Get the value of a header.
- `header.valuesOf(headerName)` - Retrieves the object containing all values of the headerName response header. Returns null if the headerName response header doesn't exist.

```javascript
client.log(response.headers.valueOf("Content-Type"));
```
