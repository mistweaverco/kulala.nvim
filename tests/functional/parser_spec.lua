---@diagnostic disable: undefined-field, redefined-local
local config = require("kulala.config")
local db = require("kulala.db")
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
        dynamic_vars.stub { ["$timestamp"] = "$TIMESTAMP" }

        h.create_buf(
          ([[
            @DEFAULT_TIMEOUT = 5000
            @REQ_USERNAME = Test_user
            @REQ_PASSWORD = Test_password
            @MY_COOKIE = awesome=me
            @page = ONE
            @VAR_NAME_TEST_abc-0123456789 = Test_var_name_ok

            POST https://httpbingo.org/basic-auth/{{REQ_USERNAME}}/{{REQ_PASSWORD}} HTTP/1.1
            Content-Type: application/json
            Accept: application/json
            Authorization: Basic {{REQ_USERNAME}}:{{REQ_PASSWORD}}
            Cookie: {{MY_COOKIE}}
            Cookie: another_cookie=me

            {
              "Timeout": {{DEFAULT_TIMEOUT}},
              "Timestamp": {{$timestamp}},
              "VarNameTest": "{{VAR_NAME_TEST_abc-0123456789}}"
            }

            >> institutions_{{page}}.json
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
          cookie = "awesome=me; another_cookie=me",
          body = ([[
            {
              "Timeout": 5000,
              "Timestamp": $TIMESTAMP,
              "VarNameTest": "Test_var_name_ok"
            }]]):to_string(true),
          redirect_response_body_to_files = {
            {
              file = "institutions_ONE.json",
            },
          },
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

      it("processes curl flags", function()
        h.create_buf(
          ([[
            ### Shared
            # @curl-compressed
            POST https://httpbingo.org/1

            ###
            # @curl-location
            # @curl-data-urlencode
            # @curl-connect-timeout 1000
            POST https://httpbingo.org/2
            Content-Type: application/json

            { "key": "value" }
      ]]):to_table(true),
          "test.http"
        )

        h.send_keys("2j")
        result = parser.parse() or {}

        assert.is_true(vim.tbl_contains(result.cmd, "--compressed"))

        h.send_keys("8j")
        result = parser.parse() or {}

        assert.is_true(vim.tbl_contains(result.cmd, "--compressed"))
        assert.is_true(vim.tbl_contains(result.cmd, "--location"))
        assert.is_true(vim.tbl_contains(result.cmd, "--data-urlencode"))
        assert.is_true(vim.tbl_contains(result.cmd, "--connect-timeout"))
        assert.is_true(vim.tbl_contains(result.cmd, "1000"))
      end)

      it("processes SSL Configuration", function()
        h.create_buf(
          ([[
            POST https://httpbingo.org/1
      ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.is_true(vim.tbl_contains(result.cmd, "--insecure"))
      end)

      it("processes urlencodes url only if it has not been done yet", function()
        h.create_buf(
          ([[
            GET https://typicode.com/todos?date=2020-01-01 12:34:56
      ]]):to_table(true),
          "test.http"
        )

        result = parser.parse() or {}
        assert.is_same("https://typicode.com/todos?date=2020-01-01%2012%3A34%3A56", result.url)

        result = parser.parse { result } or {}
        assert.is_same("https://typicode.com/todos?date=2020-01-01%2012%3A34%3A56", result.url)
      end)

      it("skips requests commented out with # ", function()
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

      it("skips lines commented out with # ", function()
        h.create_buf(
          ([[
            # @name SIMPLE REQUEST
            # GET https://httpbingo.org/simple
            POST https://httpbingo.org/simple

            {
              "test": "value"
            }
      ]]):to_table(true),
          "test.http"
        )

        result = parser.parse() or {}
        assert.is_same("POST", result.method)
      end)

      it("skips lines commented out with //", function()
        h.create_buf(
          ([[
            # @name SIMPLE REQUEST
            // GET request
            POST https://httpbingo.org/simple

            {
              "test": "value"
            }
      ]]):to_table(true),
          "test.http"
        )

        result = parser.parse() or {}
        assert.is_same("POST", result.method)
      end)

      describe("processes url", function()
        local http_buf

        before_each(function()
          http_buf = h.create_buf({}, h.expand_path("requests/simple.http"))
        end)

        local assert_url = function(lines, method, url, version)
          h.set_buf_lines(http_buf, lines)
          local msg = "Assert failed: " .. vim.inspect(lines)

          result = parser.parse() or {}

          assert.is.same(method, result.method, msg)
          assert.is.same(url, result.url, msg)
          assert.is.same(version, result.http_version, msg)

          return result
        end

        -- [method required-whitespace] request-target [required-whitespace http-version]
        it("processes request line", function()
          -- full
          assert_url({
            "POST https://httpbin.org:8080/simple?query=value#fragment HTTP/1.1",
          }, "POST", "https://httpbin.org:8080/simple?query=value#fragment", "1.1")

          --- no method, default GET
          assert_url({ "https://httpbin.org/simple HTTP/1.1" }, "GET", "https://httpbin.org/simple", "1.1")

          --- no version
          assert_url({ "https://httpbin.org/simple" }, "GET", "https://httpbin.org/simple")

          --- no scheme
          assert_url({ "httpbin.org/simple" }, "GET", "httpbin.org/simple")

          --- origin form: absolute-path [‘?’ query] [‘#’ fragment]
          assert_url(
            ([[
            GET /api/get?query=value#fragment HTTP/2
            Host: https://httpbin.org:443
          ]]):to_table(true),
            "GET",
            "https://httpbin.org:443/api/get?query=value#fragment",
            "2"
          )

          --- no scheme
          assert_url(
            ([[
            GET /api/get?query=value#fragment HTTP/2
            Host: httpbin.org
          ]]):to_table(true),
            "GET",
            "httpbin.org/api/get?query=value#fragment",
            "2"
          )

          --- asterisk form
          result = assert_url(
            ([[
            OPTIONS * HTTP/1.1
            Host: http://example.com:8080
          ]]):to_table(true),
            "OPTIONS",
            "http://example.com:8080",
            "1.1"
          )
          assert.is.same("*", result.request_target)

          assert_url({ "127.0.0.1:80" }, "GET", "127.0.0.1:80")
          assert_url({ "http://[::1]" }, "GET", "http://[::1]")

          --- muiltiline URL
          assert_url(
            ([[
              GET http://example.com:8080
                  /api
                  /html
                  /get
                  ?id=123
                  &value=content
          ]]):to_table(true),
            "GET",
            "http://example.com:8080/api/html/get?id=123&value=content"
          )

          --- default Host
          assert_url({
            "/simple",
          }, "GET", "httpbin.org/simple")
        end)

        it("urlencodes correctly", function()
          -- `!` `#` `$` `&` `'` `(` `)` `*` `+` `,` `/` `:` `;` `=` `?` `@` `[` `]` `%` reserved
          -- `?`, `&`, `=`, `/`, `#`, `:` special syntax

          assert_url(
            { "https://my.server.com/api/v1/object?filter=A BC:D&EF&G#HI=J/K&L%M#fragment" },
            "GET",
            "https://my.server.com/api/v1/object?filter=A%20BC%3AD&EF&G%23HI=J/K&L%25M#fragment"
          )
          assert_url(
            {
              [[https://my.server.com/api/v1/object?filter=owner.address.city in ["Berlin", "München", "Nürnberg"]']],
            },
            "GET",
            [[https://my.server.com/api/v1/object?filter=owner.address.city%20in%20%5B%22Berlin%22,%20%22M%C3%BCnchen%22,%20%22N%C3%BCrnberg%22%5D']]
          )
          assert_url(
            { 'httpbin.org/post?filter={"conditions":{}}' },
            "GET",
            "httpbin.org/post?filter=%7B%22conditions%22%3A%7B%7D%7D"
          )
          assert_url(
            { "httpbin.org/post(with space)/?filter=A eq 'XYZ'" },
            "GET",
            "httpbin.org/post(with%20space)/?filter=A%20eq%20'XYZ'"
          )

          config.options.urlencode = "skipencoded"
          assert_url(
            { "https://httpbin.org/Company%27WITH%20SPACE%27" },
            "GET",
            "https://httpbin.org/Company%27WITH%20SPACE%27"
          )
          config.options.urlencode = "always"
        end)
      end)

      it("processes headers", function()
        h.create_buf(
          ([[
            POST https://httpbingo.org/simple
            content-type: application/json
            Content-Type: application/x-www-form-urlencoded
            User-Agent: header with : colons and [
            Origin: https://httpbingo.org
            Empty-Header:
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result.headers, {
          Accept = "application/json",
          ["content-type"] = "application/json",
          ["Content-Type"] = "application/x-www-form-urlencoded",
          ["User-Agent"] = "header with : colons and [",
          ["Origin"] = "https://httpbingo.org",
          ["Empty-Header"] = "",
        })
      end)

      it("processes auth headers", function()
        local credentials = {
          "myuser:mypassword",
          "my user:mypassword",
          "myuser:my password",
        }

        vim.iter(credentials):each(function(cred)
          h.create_buf(
            ([[
            POST https://httpbingo.org/simple
            content-type: application/json
            Authorization: Basic %s
          ]]):format(cred):to_table(true),
            h.expand_path("requests/simple.http")
          )

          result = parser.parse() or {}

          assert.has_properties(result.headers, { ["Authorization"] = nil })
          assert.has_string(result.cmd, "-u")
          assert.has_string(result.cmd, cred)

          h.delete_all_bufs()
        end)
      end)

      it("sets headers from http-client", function()
        h.create_buf(
          ([[
            POST https://httpbingo.org/simple
            Content-Type: plain/text
            Test-Header-3: Test-Value-3
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result.headers, {
          ["Content-Type"] = "plain/text", -- from request overrides $default in $shared
          ["Accept"] = "application/json", -- from $default in $shared
          ["Test-Header"] = "Test-Value", -- from $default in dev
          ["Test-Header-3"] = "Test-Value-3", -- from request overrides $default in dev
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

      it("replaces nested variables", function()
        h.create_buf(
          ([[
            POST https://httpbin.org/post
            Token: {{deep.nested.var}}
          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}
        assert.has_properties(result, {
          headers = {
            ["Token"] = "deep-nested-variable",
          },
        })
      end)

      it("replaces variables in .json files", function()
        h.create_buf(
          ([[
          @OCCUPATION = Developer
          POST https://httpbin.org/post
          Content-Type: application/json

          < ./tests/functional/fixtures/simple.json

        ]]):to_table(true),
          "test.http"
        )

        result = parser.parse() or {}
        expected = h.load_fixture(result.body_temp_file, true)
        assert.has_string(expected, '"occupation": "Developer"')
      end)

      it("replaces variables recursively", function()
        h.create_buf(
          ([[
            @User = {{Recursive-Var}}
            @Alias = {{User}}
            POST https://httpbin.org/post/{{User}}/{{Alias}}
            User: {{User}}

          ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        result = parser.parse() or {}

        assert.has_string(result.url, "/gorillamoe/gorillamoe")
        assert.has_properties(result, {
          headers = {
            ["User"] = "gorillamoe",
            ["Test-Header-3"] = "ditto",
          },
        })
      end)

      it("saves request bdoy to a file before sending", function()
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

      describe("it processes run and import directives", function()
        local doc_parser = require("kulala.parser.document")

        -- import|run filename_in_cwd|relative_path|absolute_path
        it("run - filename", function()
          h.create_buf(
            ([[
            POST https://httpbin.org/post HTTP/1.1
            Content-Type: text/plain

            ###
            run tests/functional/requests/advanced_A.http
          ]]):to_table(true),
            "test.http"
          )

          result = doc_parser.get_document() or {}
          assert.is_same("https://httpbin.org/post", result[1].url)
          assert.is_same("https://httpbin.org/advanced_1", result[2].url)
          assert.is_same("https://httpbin.org/advanced_2", result[3].url)
        end)

        it("import/run - filename", function()
          h.create_buf(
            ([[
            import tests/functional/requests/advanced_A.http

            ### Request (zero)
            POST https://httpbin.org/post HTTP/1.1
            Content-Type: text/plain

            ###
            run #Request (zero)
            run #Request 1
            run #POST https://httpbin.org/advanced_2

            GET https://httpbin.org/get HTTP/1.1
          ]]):to_table(true),
            "test.http"
          )

          local requests = doc_parser.get_document()
          result = doc_parser.get_request_at(requests, 13) or {}

          assert.is_same("https://httpbin.org/post", result[1].url)
          assert.is_same("https://httpbin.org/advanced_1", result[2].url)
          assert.is_same("https://httpbin.org/advanced_2", result[3].url)
          assert.is_same("https://httpbin.org/get", result[4].url)
        end)

        it("run - replaces variables", function()
          -- run #GET request with two vars (@host=example.com, @user=userName)
          h.create_buf(
            ([[
            import tests/functional/requests/advanced_A.http

            POST https://httpbin.org/post HTTP/1.1
            Content-Type: text/plain

            ###
            run #Request 1 (@foobar=new_bar, @ENV_USER = new_username)
            run #POST https://httpbin.org/advanced_2
          ]]):to_table(true),
            "test.http"
          )

          h.send_keys("8j") -- Request 2
          result = parser.parse() or {}

          assert.has_properties(result.variables, {
            foobar = "new_bar",
            ENV_USER = "new_username",
            ENV_PROJECT = "project_name",
          })
        end)

        it("imports and runs nested imports/requests", function()
          h.create_buf(
            ([[
            POST https://httpbin.org/request_0
            Content-Type: text/plain
            ###
            run import.http
          ]]):to_table(true),
            h.expand_path("requests/simple.http")
          )

          result = doc_parser.get_document()
          result = doc_parser.get_request_at(result, 0) or {}

          assert.is_same(4, #result)

          local function assert_url(no, url, file)
            assert.is_same(url, result[no].url)
            assert.match(file, result[no].file)
          end

          assert_url(1, "https://httpbin.org/request_0", "simple.http")
          assert_url(2, "https://httpbin.org/advanced_b", "advanced_B.http")
          assert_url(3, "https://httpbin.org/advanced_1", "advanced_A.http")
          assert_url(4, "https://httpbin.org/imported", "import.http")
        end)
      end)

      describe("processes the shared block", function()
        before_each(function()
          h.create_buf(
            ([[
            ### Shared

            @shared_var_1 = shared_value_1
            @shared_var_2 = shared_value_2

            # @curl-connect-timeout 20
            # @curl-location

            < {%
              console.log("pre request 0")
            %}

            < ../scripts/advanced_D_pre.js

            POST https://httpbingo.org/0

            > {%
              console.log("post request 0")
            %}

            > ../scripts/advanced_D_post.js

            ### request 1

            @shared_var_2 = local_value_2
            @local_var = local_value

            # @curl-connect-timeout 10
            # @curl-data-urlencode

            POST https://httpbingo.org/1
          ]]):to_table(true),
            h.expand_path("requests/simple.http")
          )
        end)

        it("processes the shared block", function()
          h.send_keys("25j") -- request 1
          result = parser.parse() or {}

          assert.is_same("https://httpbingo.org/1", result.url)

          assert.is_same("https://httpbingo.org/0", result.shared.url)

          assert.has_properties(result.shared.variables, {
            shared_var_1 = "shared_value_1",
            shared_var_2 = "local_value_2",
          })

          assert.has_properties(result.shared.metadata, {
            { name = "curl-connect-timeout", value = "20" },
            { name = "curl-location", value = "" },
          })

          assert.has_properties(result.shared.scripts, {
            pre_request = {
              files = { h.expand_path("requests") .. "/../scripts/advanced_D_pre.js" },
              inline = { 'console.log("pre request 0")' },
              priority = "inline",
            },

            post_request = {
              files = { h.expand_path("requests") .. "/../scripts/advanced_D_post.js" },
              inline = { 'console.log("post request 0")' },
              priority = "inline",
            },
          })
        end)

        it("applies shared data", function()
          h.send_keys("25j") -- request 1
          result = parser.parse() or {}

          assert.is_same("https://httpbingo.org/1", result.url)

          assert.has_properties(result.variables, {
            shared_var_1 = "shared_value_1",
            shared_var_2 = "local_value_2",
            local_var = "local_value",
          })

          assert.has_properties(result.metadata, {
            { name = "curl-connect-timeout", value = "10" },
            { name = "curl-data-urlencode", value = "" },
            { name = "curl-location", value = "" },
          })
        end)

        it("applies variables_scope", function()
          config.options.variables_scope = "request"

          h.send_keys("25j") -- request 1
          result = parser.parse() or {}

          config.options.variables_scope = "document"

          assert.is_same("https://httpbingo.org/1", result.url)

          assert.has_properties(result.shared.variables, {
            shared_var_1 = "shared_value_1",
            shared_var_2 = "shared_value_2",
          })

          assert.has_properties(result.variables, {
            shared_var_2 = "local_value_2",
            local_var = "local_value",
          })
        end)
      end)

      describe("processes http-client.env.json", function()
        before_each(function()
          h.create_buf(([[ POST https://httpbingo.org/0 ]]):to_table(true), h.expand_path("requests/simple.http"))
        end)

        after_each(function()
          h.delete_all_bufs()
        end)

        it("processes http-client.env.json", function()
          result = parser.parse() or {}

          local shared_env = db.find_unique("http_client_env_shared") or {}
          local dev_env = db.find_unique("http_client_env")["dev"] or {}
          local prod_env = db.find_unique("http_client_env")["prod"] or {}

          assert.has_properties(shared_env, {
            ["$default_headers"] = {
              Accept = "application/json",
              Origin = "httpbin.org",
            },
            DEFAULT_TIMEOUT = 1,
          })

          assert.has_properties(dev_env, {
            ["$default_headers"] = {
              ["Test-Header"] = "Test-Value",
            },
            PASSWORD = "bananas",
            pokemon_root = "ditto",
            Security = {
              Auth = {
                GAPI = {
                  ["Auth URL"] = "https://auth.url",
                },
              },
            },
          })

          assert.has_properties(prod_env, {
            PASSWORD = "polo",
            pokemon_root = "pikachu",
          })
        end)
      end)
    end)
  end)
end)
