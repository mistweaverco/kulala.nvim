local M = {
  -- cURL path
  -- if you have curl installed in a non-standard path,
  -- you can specify it here
  curl_path = "curl",
  -- additional cURL options
  -- see: https://curl.se/docs/manpage.html
  additional_curl_options = {},
  -- gRPCurl path, get from https://github.com/fullstorydev/grpcurl.git
  grpcurl_path = "grpcurl",
  -- websocat path, get from https://github.com/vi/websocat.git
  websocat_path = "websocat",
  -- openssl path
  openssl_path = "openssl",

  -- set scope for environment and request variables
  -- possible values: b = buffer, g = global
  environment_scope = "b",
  -- dev, test, prod, can be anything
  -- see: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files
  default_env = "dev",
  -- enable reading vscode rest client environment variables
  vscode_rest_client_environmentvars = false,

  -- default timeout for the request, set to nil to disable
  request_timeout = nil,
  -- continue running requests when a request failure is encountered
  halt_on_error = true,

  -- certificates
  certificates = {},
  -- Specify how to escape query parameters
  -- possible values: always, skipencoded = keep %xx as is
  urlencode = "always",

  -- default formatters/pathresolver for different content types
  contenttypes = {
    ["application/json"] = {
      ft = "json",
      formatter = vim.fn.executable("jq") == 1 and { "jq", "." },
      pathresolver = function(...)
        return require("kulala.parser.jsonpath").parse(...)
      end,
    },
    ["application/xml"] = {
      ft = "xml",
      formatter = vim.fn.executable("xmllint") == 1 and { "xmllint", "--format", "-" },
      pathresolver = vim.fn.executable("xmllint") == 1 and { "xmllint", "--xpath", "{{path}}", "-" },
    },
    ["text/html"] = {
      ft = "html",
      formatter = vim.fn.executable("xmllint") == 1 and { "xmllint", "--format", "--html", "-" },
      pathresolver = nil,
    },
  },

  ui = {
    -- display mode: possible values: "split", "float"
    display_mode = "split",
    -- split direction: possible values: "vertical", "horizontal"
    split_direction = "vertical",
    -- window options to override defaults: width/height/split/vertical
    win_opts = {},
    -- default view: "body" or "headers" or "headers_body" or "verbose" or fun(response: Response)
    default_view = "body",
    -- enable winbar
    winbar = true,
    -- Specify the panes to be displayed by default
    -- Current available pane contains { "body", "headers", "headers_body", "script_output", "stats", "verbose", "report", "help" },
    default_winbar_panes = { "body", "headers", "headers_body", "verbose", "script_output", "report", "help" },
    -- enable/disable variable info text
    -- this will show the variable name and value as float
    -- possible values: false, "float"
    show_variable_info_text = false,
    -- icons position: "signcolumn"|"on_request"|"above_request"|"below_request" or nil to disable
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
    },

    -- enable/disable request summary in the output window
    show_request_summary = true,
    -- disable notifications of script output
    disable_script_print_output = false,

    report = {
      -- possible values: true | false | "on_error"
      show_script_output = true,
      -- possible values: true | false | "on_error" | "failed_only"
      show_asserts_output = true,
      -- possible values: true | false | "on_error"
      show_summary = true,

      headersHighlight = "Special",
      successHighlight = "String",
      errorHighlight = "Error",
    },

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

    disable_news_popup = false,
  },

  -- enable/disable debug mode
  debug = 3,

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

return M
