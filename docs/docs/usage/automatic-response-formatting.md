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

Below are the default formatters provided by Kulala:

```lua
  contenttypes = {
    ["application/json"] = {
      ft = "json",
      formatter = vim.fn.executable("jq") == 1 and { "jq", "." },
      pathresolver = function(...)
        return require("kulala.parser.jsonpath").parse(...)
      end,
    },
    ["application/graphql"] = {
      ft = "graphql",
      formatter = vim.fn.executable("prettier") == 1 and { "prettier", "--stdin-filepath", "file.graphql" },
      pathresolver = nil,
    },
    ["application/javascript"] = {
      ft = "javascript",
      formatter = vim.fn.executable("prettier") == 1 and { "prettier", "--stdin-filepath", "file.js" },
      pathresolver = nil,
    },
    ["application/lua"] = {
      ft = "lua",
      formatter = vim.fn.executable("stylua") == 1 and { "stylua", "-" },
      pathresolver = nil,
    },
    ["application/graphql-response+json"] = "application/json",
    ["application/xml"] = {
      ft = "xml",
      formatter = vim.fn.executable("xmllint") == 1 and { "xmllint", "--format", "-" },
      pathresolver = vim.fn.executable("xmllint") == 1 and { "xmllint", "--xpath", "{{path}}", "-" },
    },
    ["text/html"] = {
      ft = "html",
      formatter = vim.fn.executable("prettier") == 1 and { "prettier", "--stdin-filepath", "file.html" },
      pathresolver = nil,
    },
  },
```

Note that you can refer to other content types by using their string key, like shown in the example for `application/graphql-response+json`.  

The keys are regex matched against the `Content-Type` header, so you can also define custom content types, like in the example below, which will 
match compound headers, like `application/json; charset=utf-8` as well.

```lua
contenttypes = {
  ["json"] = "application/json",
},
```
