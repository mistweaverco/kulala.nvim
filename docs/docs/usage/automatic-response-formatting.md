# Automatic Response Formatting

You can automatically format the response of an HTTP request.

The response header will be parsed for the `Content-Type` value.
If the content type has been defined in
the `contentypes` section of the configuration.

If there is a `formatter` available,
the response will be processed by the given beautifier.

:::info

You need to have external tools to format the response, 
for example `jq` for JSON or `xmllint` for XML and HTML,
or you implement a lua function.

:::

### Default formatters

By default there are formatters defined for following types:

- `application/json`
- `application/xml`
- `text/html`

For details see the configuration section.
