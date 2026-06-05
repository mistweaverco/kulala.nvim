# Custom Curl Flags

- You can customize the curl command used to make requests in Kulala, on a per-request basis or globally for all requests in a buffer, if included in the `KULALA_SHARED` block.

## Usage

Use `# @kulala-curl-..` prefix, followed by the curl flag you want to use.

```http
# @kulala-curl--compressed
# @kulala-curl--non-buffer
# @kulala-curl--location

GET /api/get
Host: example.com
```

:::info

If you need to apply curl flags to OAuth requests, you have to put it into `KULALA_SHARED` block.

:::

### Some common curl flags you might want to use:

- `# @kulala-curl--compressed`: Automatically decompresses the response.
- `# @kulala-curl--no-buffer`: Disables buffering for the request.
- `# @kulala-curl--location`: Follows redirects.
- `# @kulala-curl--insecure`: Allows insecure SSL connections.
- `# @kulala-curl--data-urlencode`: Encodes the request body as application/x-www-form-urlencoded.
- `# @kulala-curl--connect-timeout`: Sets the maximum time in seconds that the connection phase can take.
