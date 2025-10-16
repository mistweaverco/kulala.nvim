# Custom Curl Flags

- You can customize the curl command used to make requests in Kulala, on a per-request basis or globally for all requests in a buffer, if included in the `Shared` block.

## Usage

Use `# @curl-..` prefix, followed by the curl flag you want to use.

```http
# @curl-compressed
# @curl-non-buffer
# @curl-location

GET /api/get
Host: example.com
```

:::info

If you need to apply curl flags to OAuth requests, you have to put it into `Shared` block.

:::

### Some common curl flags you might want to use:

- `# @curl-compressed`: Automatically decompresses the response.
- `# @curl-no-buffer`: Disables buffering for the request.
- `# @curl-location`: Follows redirects.
- `# @curl-insecure`: Allows insecure SSL connections.
- `# @curl-data-urlencode`: Encodes the request body as application/x-www-form-urlencoded.
- `# curl-connect-timeout`: Sets the maximum time in seconds that the connection phase can take.
