local FS = require("kulala.utils.fs")
local keymaps = require("kulala.config.keymaps")
local M = {}

M.defaults = {
  -- cURL path
  -- if you have curl installed in a non-standard path,
  -- you can specify it here
  curl_path = "curl",

  -- gRPCurl path, get from https://github.com/fullstorydev/grpcurl
  grpcurl_path = "grpcurl",
  -- Display mode
  -- possible values: "split", "float"
  display_mode = "split",
  -- split direction
  -- possible values: "vertical", "horizontal"
  split_direction = "vertical",
  -- default_view, body or headers or headers_body or verbose or fun(response: Response)
  default_view = "body",
  -- dev, test, prod, can be anything
  -- see: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
  default_env = "dev",
  -- enable/disable debug mode
  debug = false,
  -- default timeout for the request, set to nil to disable
  request_timeout = nil,
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
  -- icons postion: singcolumn|on_request|above_request|below_request or nil to disable
  show_icons = "on_request",
  -- default icons
  icons = {
    inlay = {
      loading = "⏳",
      done = "✅",
      error = "❌",
    },
    lualine = "🐼",
    textHighlight = "WarningMsg", -- highlight group for request elapsed time
    lineHighlight = "Normal", -- highlight group for icons line highlight
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
  -- Current available pane contains { "body", "headers", "headers_body", "script_output", "stats", "verbose" },
  default_winbar_panes = { "body", "headers", "headers_body", "verbose" },
  -- enable reading vscode rest client environment variables
  vscode_rest_client_environmentvars = false,
  -- parse requests with tree-sitter
  treesitter = false,
  -- disable the vim.print output of the scripts
  -- they will be still written to disk, but not printed immediately
  disable_script_print_output = false,
  -- set scope for environment and request variables
  -- possible values: b = buffer, g = global
  environment_scope = "b",
  -- certificates
  certificates = {},
  -- Specify how to escape query parameters
  -- possible values: always, skipencoded = keep %xx as is
  urlencode = "always",
  -- enable/disable variable info text
  -- this will show the variable name and value as float
  -- possible values: false, "float"
  show_variable_info_text = false,

  -- set to true to enable default keymaps (check docs or {plugins_path}/kulala.nvim/lua/kulala/config/keymaps.lua for details)
  -- or override default keymaps as shown in the example below.
  ---@type boolean|table
  global_keymaps = false,
  --[[
    {
      ["Send request"] = { -- sets global mapping
        "<leader>Rs",
        function() require("kulala").run() end,
        mode = { "n", "v" }, -- optional mode, default is n
        desc = "Send request" -- optional description, otherwise inferred from the key
      },
      ["Send all requests"] = {
        "<leader>Ra",
        function() require("kulala").run_all() end,
        mode = { "n", "v" },
        ft = "http", -- sets mapping for *.http files only
      },
      ["Replay the last request"] = {
        "<leader>Rr",
        function() require("kulala").replay() end,
        ft = { "http", "rest" }, -- sets mapping for specified file types
      },
    ["Find request"] = false -- set to false to disable
    },
  ]]

  -- Kulala UI keymaps, override with custom keymaps as required (check docs or {plugins_path}/kulala.nvim/lua/kulala/config/keymaps.lua for details)
  ---@type boolean|table
  kulala_keymaps = true,
  --[[
    {
      ["Show headers"] = { "H", function() require("kulala.ui").show_headers() end, },
    }
  ]]
}

M.default_contenttype = {
  ft = "text",
  formatter = nil,
  pathresolver = nil,
}

M.options = M.defaults

local function set_signcolumn_icons()
  local linehl = M.options.icons.lineHighlight

  vim.fn.sign_define({
    { name = "kulala.done", text = M.options.icons.inlay.done, linehl = linehl },
    { name = "kulala.error", text = M.options.icons.inlay.error, linehl = linehl },
    { name = "kulala.loading", text = M.options.icons.inlay.loading, linehl = linehl },
    { name = "kulala.space", text = " " },
  })
end

M.setup = function(config)
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})

  set_signcolumn_icons()
  M.options.global_keymaps, M.options.ft_keymaps = keymaps.setup_global_keymaps()

  return M.options
end

M.set = function(config)
  M.options = vim.tbl_deep_extend("force", M.options, config or {})
end

M.get = function()
  return M.options
end

return M
