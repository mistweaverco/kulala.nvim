---@diagnostic disable: undefined-field, redefined-local
local fs = require("kulala.utils.fs")
local h = require("test_helper")
local parser = require("kulala.parser.request")

describe("requests", function()
  describe("show output of requests", function()
    local dynamic_vars
    local result, expected

    before_each(function()
      dynamic_vars = h.Dynamic_vars.stub()
    end)

    after_each(function()
      h.delete_all_bufs()
      dynamic_vars.reset()
      fs.delete_request_scripts_files()
    end)

    describe("parser", function()
      it("processes document variables", function()
        dynamic_vars.stub({ ["$timestamp"] = "$TIMESTAMP" })

        h.create_buf(
          ([[
            @DEFAULT_TIMEOUT = 5000
            @REQ_USERNAME = Test_user
            @REQ_PASSWORD = Test_password

            POST https://httpbingo.org/basic-auth/{{REQ_USERNAME}}/{{REQ_PASSWORD}} HTTP/1.1
            Content-Type: application/json
            Accept: application/json
            Authorization: Basic {{REQ_USERNAME}}:{{REQ_PASSWORD}}

            {
              "Timeout": {{DEFAULT_TIMEOUT}},
              "Timestamp": {{$timestamp}}
            }
      ]]):to_table(true),
          "test.http"
        )

        result = parser.parse() or {}
        assert.has_properties(result, {
          url = "https://httpbingo.org/basic-auth/Test_user/Test_password",
          method = "POST",
          headers_display = {
            ["Accept"] = "application/json",
            ["Authorization"] = "Basic Test_user:Test_password",
            ["Content-Type"] = "application/json",
          },
          body = ([[
            {
              "Timeout": 5000,
              "Timestamp": $TIMESTAMP
            }]]):to_string(true),
        })
      end)

      it("processes metadata", function()
        h.create_buf(
          ([[
            # @name SIMPLE REQUEST
            POST https://httpbingo.org/simple
            Content-Type: application/json
            Accept: application/json
      ]]):to_table(true),
          "test.http"
        )

        result = parser.parse() or {}
        assert.has_properties(result, {
          metadata = { {
            name = "name",
            value = "SIMPLE REQUEST",
          } },
        })
      end)

      it("skips reequests comented out with # ", function()
        h.create_buf(
          ([[
            # @name SIMPLE REQUEST
            #POST https://httpbingo.org/simple
            Content-Type: application/json
            Accept: application/json
      ]]):to_table(true),
          "test.http"
        )

        result = parser.parse() or {}
        assert.is.same({}, result)
      end)

      it("processes headers", function()
        h.create_buf(
          ([[
            POST https://httpbingo.org/simple
            content-type: application/json
            Content-Type: application/x-www-form-urlencoded
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result.headers, {
          Accept = "application/json",
          ["content-type"] = "application/json",
          ["Content-Type"] = "application/x-www-form-urlencoded",
        })
      end)

      it("processes multipart-form", function()
        h.create_buf(
          ([[
            POST https://httpbingo.org/simple
            Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

            ------WebKitFormBoundary
            Content-Disposition: form-data; name="x"

            0
            ------WebKitFormBoundary
            Content-Disposition: form-data; name="y"

            1.4333333333333333
            ------WebKitFormBoundary--
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result, {
          body_computed = '------WebKitFormBoundary\r\nContent-Disposition: form-data; name="x"\r\n\r\n0\r\n------WebKitFormBoundary\r\nContent-Disposition: form-data; name="y"\r\n\r\n1.4333333333333333\r\n------WebKitFormBoundary--',
          headers = {
            ["Content-Type"] = "multipart/form-data; boundary=----WebKitFormBoundary",
          },
        })
      end)

      it("processes form-urlencoded", function()
        h.create_buf(
          ([[
            POST https://httpbin.org/post HTTP/1.1
            Content-Type: application/x-www-form-urlencoded

            foo=bar&

            bar=baz
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result, {
          body_computed = "foo=bar&bar=baz",
          headers = {
            Accept = "application/json",
            ["Content-Type"] = "application/x-www-form-urlencoded",
          },
        })
      end)

      it("processes pre_request_scripts", function()
        h.create_buf(
          ([[
            < {%
            request.variables.set('TOKEN_RAW', '--ATOKEN--');
            %}
            < ../scripts/advanced_D_pre.js
            POST https://httpbin.org/post?key1=URLvalueXXX HTTP/1.1
            Content-Type: application/json
            Token: {{COMPUTED_TOKEN}}
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result, {
          headers = {
            ["Token"] = "POST--ATOKEN--URLvalueXXX125000",
          },
        })
      end)

      it("processes graphQL queries", function()
        h.create_buf(
          ([[
            POST https://swapi-graphql.netlify.app/graphql HTTP/1.1
            X-REQUEST-TYPE: GraphQL

            query Person($id: ID) {
              person(personID: $id) {
                name
              }
            }

            {
              "id": 1
            }
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result, {
          headers = {
            ["Content-Type"] = "application/json",
            ["X-REQUEST-TYPE"] = "GraphQL",
          },
        })
        assert.has_string(result.body_computed, '"variables":{"id":1}')
        assert.has_string(result.body_computed, '"query":"query Person($id: ID) { person(personID: $id) { name } } "')
      end)

      it("processes file includes with < file/path", function()
        h.create_buf(
          ([[
            POST https://httpbin.org/post HTTP/1.1
            Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

            ------WebKitFormBoundary
            Content-Disposition: form-data; name="someFile"; filename="logo.png"
            Content-Type: image/jpeg

            < ./demo.png

            ------WebKitFormBoundary
            Content-Disposition: form-data; name="someFile"; filename="logo.png"
            Content-Type: image/jpeg

            < ./demo-missing.png

            ------WebKitFormBoundary--
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_string(result.body_computed, "< " .. h.expand_path("requests/demo.png"))
        assert.has_string(result.body_computed, "< [file not found] " .. h.expand_path("requests/demo-missing.png"))

        expected = h.load_fixture("requests/demo.png", true)
        assert.has_string(h.load_fixture(result.body_temp_file, true), expected)
      end)

      it("saves the request to a file", function()
        h.create_buf(
          ([[
            POST https://httpbin.org/post HTTP/1.1
            Content-Type: text/plain

            Sample POST request body

          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.is_same(h.load_fixture(result.body_temp_file, true), "Sample POST request body")
      end)

      it("redirects response to a file", function()
        h.create_buf(
          ([[
            POST https://httpbin.org/post HTTP/1.1
            Content-Type: text/plain

            Sample POST request body

            >> ./response.txt
            >>! ./response_overwrite.txt

          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result, {
          redirect_response_body_to_files = {
            { file = "./response.txt", overwrite = false },
            { file = "./response_overwrite.txt", overwrite = true },
          },
        })
      end)
    end)
  end)
end)
