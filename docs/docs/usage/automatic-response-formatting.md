# Automatic Response Formatting

You can automatically format the response of an HTTP request using the `accept` header.

For example, if you want to receive the response in JSON format, you can add the `accept: application/json` header.

```http title="automatic-response-formatting.http"
POST https://httpbin.org/post HTTP/1.1
content-type: application/json
accept: application/json

{
  "uuid": "{{$uuid}}",
  "timestamp": "{{$timestamp}}",
  "date": "{{$date}}",
  "randomInt": "{{$randomInt}}",
}

```
:::info

You need to have external tools to format the response.
For example, `jq` for JSON, `xmllint` for XML and HTML, etc.

:::

### Supported Formats

- JSON: `application/json`
- XML: `application/xml`
- HTML: `text/html`

### Default formatters

```lua title="default-formatters.lua"
formatters = {
  json = { "jq", "." },
  xml = { "xmllint", "--format", "-" },
  html = { "xmllint", "--format", "--html", "-" },
}
```
