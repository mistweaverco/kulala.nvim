---@diagnostic disable: undefined-field, redefined-local

local config = require("kulala.config")
local formatter = require("kulala.formatter.formatter")

local h = require("test_helper")

-- set to true to update the parser in .tests
local function setup_http_parser(update)
  config.setup()
  if update then require("nvim-treesitter.install").commands.TSUpdateSync["run"]("kulala_http") end
end

describe("format", function()
  local buf, result, document

  setup(function()
    setup_http_parser()
  end)

  before_each(function()
    h.delete_all_bufs()
    buf = h.create_buf(h.load_fixture("fixtures/format.http"):to_table(), "format.http")
  end)

  describe("formats buffer", function()
    before_each(function()
      config.options.lsp.formatter.sort.commands = true
      result, document = formatter.format(buf)
      result = result[1].newText or {}
    end)

    it("formats request separator", function()
      local section = document.sections[2]
      assert.is_same(section.request_separator, "### Request name")
    end)

    it("formats variables", function()
      local section = document.sections[1]
      assert.is_same(section.variables[1], "@ENV_PROJECT = project_name")
    end)

    it("formats metadata", function()
      local section = document.sections[2]
      assert.is_same(section.metadata[1], "# @curl-conect-timeout 200")
    end)

    it("formats commands", function()
      local section = document.sections[3]
      assert.is_same(section.commands[1], "import ./export/simple.http")
    end)

    it("formats request", function()
      local section = document.sections[3].request
      assert.is_same(section.url, "GET http://httpbin.org/post HTTP/1.1")
      assert.has_properties(section.headers, {
        "Content-Type: application/json",
        "Accept: application/json",
      })
    end)

    it("formats pre_request", function()
      local section = document.sections[3]

      result = section.request.pre_request_script
      assert.has_properties(result, {
        "< ../scripts/post.js",
        '< {%\n  client.log("post request executed");\n%}',
      })

      result = section.request.res_handler_script
      assert.has_properties(result, {
        "> ../scripts/post.js",
        '> {%\n  client.log("post request executed");\n%}',
      })
    end)

    it("formats raw body", function()
      result = document.sections[5].request.body
      assert.is_same(
        result,
        ([[
        grant_type=password&
        username=foo&
        password=bar&
        client_id=foo]]):to_string(true)
      )
    end)

    it("formats multi-part body", function()
      result = document.sections[4].request.body
      assert.is_same(
        result,
        ([[
          ------WebKitFormBoundary{{$timestamp}}
          Content-Disposition: form-data; name="file"; filename="{{filename}}"
          Content-Type: {{content_type}}

          < {{filepath}}

          ------WebKitFormBoundary{{$timestamp}}--
        ]]):deindent(10)
      )
    end)

    it("formats json body", function()
      result = document.sections[3].request.body
      assert.is_same(
        result,
        ([[
          {
            "results": [
              {
                "desc": "some_username",
                "id": 1
              },
              {
                "desc": "another_username",
                "id": 2
              }
            ]
          }
        ]]):deindent(10)
      )
    end)

    it("formats xml body", function()
      result = document.sections[7].request.body
      assert.is_same(
        ([[
          <?xml version="1.0"?>
          <note>
            <to>Tove</to>
            <from>Jani</from>
            <heading>Reminder</heading>
            <body>Don't forget me this weekend!</body>
          </note>
        ]]):deindent(10),
        result
      )
    end)

    it("formats graphql body", function()
      result = document.sections[6].request.body
      assert.is_same(
        result,
        ([[
          query GetCountry($code: ID!) {
            country(code: $code) {
              name
              code
              capital
              capital
              currency
              languages {
                code
                name
              }
            }
          }

          {
            "code": "US"
          }
        ]]):deindent(10)
      )
    end)

    it("formats external body", function()
      result = document.sections[8].request.body
      assert.is_same(result, "< ./simple.json")
    end)

    it("formats buffer", function()
      assert.is_same(result, h.load_fixture("fixtures/formatted.http"))
    end)

    it("allows blocks without url", function()
      h.delete_all_bufs()
      buf = h.create_buf(
        ([[
        ### Shared

        @ENV_PROJECT = project_name
        # @curl-connect-timeout 200

        run ./export/simple.http

        < {%
          console.log("pre request 0");
        %}

        < ./tests/functional/scripts/advanced_E_pre.js
      ]]):to_table(true),
        "format.http"
      )

      h.get_buf_lines(buf)
      result, document = formatter.format(buf)
      result = result[1].newText or {}

      assert.is_same(
        ([[
          ### Shared

          @ENV_PROJECT = project_name

          run ./export/simple.http

          # @curl-connect-timeout 200

          < {%
            console.log("pre request 0");
          %}

          < ./tests/functional/scripts/advanced_E_pre.js
        ]]):deindent(10),
        result
      )
    end)
  end)

  describe("formats json", function()
    it("quotes variables in json body", function()
      h.delete_all_bufs()
      buf = h.create_buf(
        ([[
          http://httpbin.org/post

          {
            "test": {{TEST}},
            "example": "example {{EXAMPLE}}",
            "whatever":     "{{WHATEVER}} whatever",
            "another": [
              {
                "test": 1,
                "some": "thing {{THING}}",
                "foo": "{{BAR}}"
              }
            ],
            "foo": {{BAR}},
            "array": [ {{THING}}, "some {{THING}}"]
          }

        ]]):to_table(true),
        "format.http"
      )

      h.get_buf_lines(buf)
      result, document = formatter.format(buf)
      result = result[1].newText or {}

      assert.is_same(
        ([[
          ### 

          GET http://httpbin.org/post HTTP/1.1

          {
            "another": [
              {
                "foo": "{{BAR}}",
                "some": "thing {{THING}}",
                "test": 1
              }
            ],
            "array": [
              "{{THING}}",
              "some {{THING}}"
            ],
            "example": "example {{EXAMPLE}}",
            "foo": "{{BAR}}",
            "test": "{{TEST}}",
            "whatever": "{{WHATEVER}} whatever"
          }
        ]]):deindent(10),
        result
      )
    end)
  end)
end)
