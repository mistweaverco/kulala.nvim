local FS = require("kulala.utils.fs")
local M = {}

M.defaults = {
  -- split direction
  -- possible values: "vertical", "horizontal"
  split_direction = "vertical",
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
  show_icons = "on_request",
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
    "# @name scratchpad",
    "POST https://httpbin.org/post HTTP/1.1",
    "accept: application/json",
    "content-type: application/json",
    "",
    "{",
    '  "foo": "bar"',
    "}",
  },
  -- enable winbar
  winbar = false,
  -- Specify the panes to be displayed by default
  -- Current avaliable pane contains { "body", "headers", "headers_body", "script_output" },
  default_winbar_panes = { "body", "headers", "headers_body" },
  -- enable reading vscode rest client environment variables
  vscode_rest_client_environmentvars = false,
  -- parse requests with tree-sitter
  treesitter = false,
  -- disable the vim.print output of the scripts
  -- they will be still written to disk, but not printed immediately
  disable_script_print_output = false,
}

M.default_contenttype = {
  ft = "text",
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
