# Custom Curl Flags

- You can customize the curl command used to make requests in Kulala, on a per-request basis or globally for all requests in a buffer.

## Usage

- Local flags: `@curl-..` apply for current request only.
- Global flags: `@curl-global-..` apply for all requests in the buffer. Global settings will persist until the buffer is closed or globals are cleared with `<leaderRx>`.

```http
# @curl-global-compressed
# @curl-global-non-buffer

# @curl-location
GET /api/get
Host: example.com
```

:::warning

Flags set in variables override flags set in metatadata, which in turn override global flags.

:::
