# Scripts response reference

These helper functions are available in the response object in scripts.

- `reponse.body` - The response body, as a string, or json object if the response is json.
- `response.headers.valueOf(headerName)` - Get the value of a header.
- `response.headers.valuesOf(headerName)` - Retrieves the array containing all values of the headerName response header. Returns an empty array if the headerName response header does not exist.
