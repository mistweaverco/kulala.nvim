# Custom Curl Flags

- You can customize the curl command used to make requests in Kulala, on a per-request basis or globally for all requests in a buffer.

## Usage

- Local flags: `@curl-..` apply for current request only.
- Global flags: `@curl-global-..` apply when running all requests in a buffer.

```http
# @curl-global-compressed
# @curl-global-non-buffer

# @curl-location
GET /api/get
Host: example.com
```

:::warning

Local flags take precedence over global flags.

Make sure that global flags are not separated by `###` from the first request.

:::
