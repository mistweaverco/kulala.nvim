local FS = require("kulala.utils.fs")
local M = {}

M.defaults = {
  -- default_view, body or headers or headers_body
  default_view = "body",
  -- dev, test, prod, can be anything
  -- see: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
  default_env = "dev",
  -- enable/disable debug mode
  debug = false,
  -- default formatters/pathresolver for different content types
  contenttypes = {
    ["application/json"] = {
      ft = "json",
      formatter = FS.command_exists("jq") and { "jq", "." } or nil,
      pathresolver = require("kulala.parser.jsonpath").parse,
    },
    ["application/xml"] = {
      ft = "xml",
      formatter = FS.command_exists("xmllint") and { "xmllint", "--format", "-" } or nil,
      pathresolver = FS.command_exists("xmllint") and { "xmllint", "--xpath", "{{path}}", "-" } or nil,
    },
    ["text/html"] = {
      ft = "html",
      formatter = FS.command_exists("xmllint") and { "xmllint", "--format", "--html", "-" } or nil,
      pathresolver = nil, 
    },
  },
  -- default icons
  icons = {
    inlay = {
      loading = "⏳",
      done = "✅",
      error = "❌",
    },
    lualine = "🐼",
  },
  -- additional cURL options
  -- see: https://curl.se/docs/manpage.html
  additional_curl_options = {},
  -- scratchpad default contents
  scratchpad_default_contents = {
    "@MY_TOKEN_NAME=my_token_value",
    "",
    "POST https://httpbin.org/post HTTP/1.1",
    "accept: application/json",
    "content-type: application/json",
    "# @name scratchpad",
    "",
    "{",
    '  "foo": "bar"',
    "}",
  },
  -- enable winbar
  winbar = false;
}

M.default_contenttype = {
  ft = "plaintext",
  formatter = nil,
  pathresolver = nil,
}

M.options = {}

M.setup = function(config)
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})
end

M.set = function(config)
  M.options = vim.tbl_deep_extend("force", M.options, config or {})
end

M.get = function()
  return M.options
end

return M
