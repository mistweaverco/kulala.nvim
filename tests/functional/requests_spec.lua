---@diagnostic disable: undefined-field, redefined-local
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local Fs = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local kulala = require("kulala")

local kulala_name = GLOBALS.UI_ID
local kulala_config

local h = require("test_helper")

assert.is_true(vim.fn.executable("npm") == 1)

local function last_response()
  return DB.global_data.responses[#DB.global_data.responses]
end

describe("requests", function()
  describe("show output of requests", function()
    local curl, system, wait_for_requests
    local input, notify, dynamic_vars
    local result, expected, ui_buf

    teardown(function()
      Fs.delete_file(Fs.get_global_scripts_variables_file_path())
    end)

    before_each(function()
      h.delete_all_bufs()

      input = h.Input.stub()
      notify = h.Notify.stub()
      dynamic_vars = h.Dynamic_vars.stub()

      curl = h.Curl.stub {
        ["*"] = {
          stats = h.load_fixture("fixtures/stats.json"),
          headers = h.load_fixture("fixtures/request_2_headers.txt"),
        },
        ["http://localhost:3001/request_1"] = {
          body = h.load_fixture("fixtures/request_1_body.txt"),
          errors = h.load_fixture("fixtures/request_1_errors.txt"),
        },
        ["http://localhost:3001/request_2"] = {
          body = h.load_fixture("fixtures/request_2_body.txt"),
          errors = h.load_fixture("fixtures/request_2_errors.txt"),
        },
      }

      system = h.System.stub({ "curl" }, {
        on_call = function(system)
          curl.request(system)
        end,
      })

      wait_for_requests = function(requests_no, predicate)
        system:wait(3000, function()
          ui_buf = vim.fn.bufnr(kulala_name)
          return curl.requests_no == requests_no and ui_buf > 0 and (predicate == nil or predicate())
        end)
      end

      kulala_config = CONFIG.setup {
        default_view = "body",
        display_mode = "split",
        debug = true,
      }
    end)

    after_each(function()
      h.delete_all_bufs()
      curl.reset()
      system.reset()
      input.reset()
      notify.reset()
      dynamic_vars.reset()
    end)

    it("it substitutes document variables and does authorization", function()
      vim.cmd.edit(h.expand_path("requests/simple.http"))

      curl.stub {
        ["https://httpbin.org/simple"] = {
          body = h.load_fixture("fixtures/simple_body.txt"),
        },
      }

      kulala.run()
      wait_for_requests(1)

      local expected_request = h.load_fixture("fixtures/simple_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/simple_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.url, computed_request.url)
      assert.is_same(expected_request.headers, computed_request.headers)
      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.has_string(result, expected)
    end)

    it("sets env variable with @env-stdin-cmd", function()
      vim.cmd.edit(h.expand_path("requests/chain.http"))

      curl.stub {
        ["https://httpbin.org/chain_1"] = {
          body = h.load_fixture("fixtures/chain_1_body.txt"),
        },
        ["https://httpbin.org/chain_2"] = {
          body = h.load_fixture("fixtures/chain_2_body.txt"),
        },
      }

      kulala.run_all()
      wait_for_requests(2)

      local expected_request = h.load_fixture("fixtures/chain_2_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/chain_2_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(2, curl.requests_no)
      assert.has_string(result, expected)
    end)

    it("filters response with @jq", function()
      h.create_buf(
        ([[
          # @jq { "Content": .headers["Content-Type"], "url": .url }
          GET https://httpbin.org/simple
      ]]):to_table(true),
        "test.http"
      )

      curl.stub {
        ["https://httpbin.org/simple"] = {
          body = h.load_fixture("fixtures/simple_body.txt"),
        },
      }

      kulala.run_all()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      assert.has_string(result, 'JQ Filter: { "Content": .headers["Content-Type"], "url": .url }')

      assert.is_same("application/json", last_response().json.Content)
      assert.is_same("https://httpbin.org/simple", last_response().json.url)

      assert.has_string(result, '"Content": "application/json"')
      assert.has_string(result, '"url": "https://httpbin.org/simple"')
    end)

    it("sets environment variables from response", function()
      vim.cmd.edit(h.expand_path("requests/advanced_A.http"))

      curl.stub {
        ["https://httpbin.org/advanced_1"] = {
          body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
        },
        ["https://httpbin.org/advanced_2"] = {
          body = h.load_fixture("fixtures/advanced_A_2_body.txt"),
        },
      }

      kulala.run_all()
      wait_for_requests(2)

      local expected_request = h.load_fixture("fixtures/advanced_A_2_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_A_2_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(2, curl.requests_no)
      assert.has_string(result, expected)
    end)

    it("substitutes http.client.json variables, accesses request/response from js and logs to client", function()
      vim.cmd.edit(h.expand_path("requests/advanced_B.http"))

      curl.stub {
        ["https://httpbin.org/advanced_b"] = {
          body = h.load_fixture("fixtures/advanced_B_body.txt"),
        },
      }

      kulala.run_all()
      wait_for_requests(1)

      local expected_request = h.load_fixture("fixtures/advanced_B_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_B_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.headers, computed_request.headers)
      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.has_string(result, expected)
      assert.has_string(notify.messages, "Foobar")
      assert.has_string(notify.messages, "Thu, 30 Jan 2025 16:21:56 GMT")
    end)

    it("prompts for vars, computes request vars, logs to client", function()
      vim.cmd.edit(h.expand_path("requests/advanced_D.http"))

      input.stub { ["Password prompt"] = "TEST_PASSWORD" }
      curl.stub {
        ["https://httpbin.org/advanced_d"] = {
          body = h.load_fixture("fixtures/advanced_D_body.txt"),
        },
      }

      kulala.run_all()
      wait_for_requests(1)

      local expected_request = h.load_fixture("fixtures/advanced_D_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_D_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.headers, computed_request.headers)
      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.has_string(notify.messages, "Content-Type:application/json")
      assert.has_string(notify.messages, "{ someHeaderValue: 'gunicorn/19.9.0' }")
      assert.has_string(result, expected)
    end)

    it("has access to request and response data through request variables", function()
      vim.cmd.edit(h.expand_path("requests/advanced_F.http"))

      curl.stub {
        ["*"] = {
          headers = h.load_fixture("fixtures/advanced_F_headers.txt"),
          body = h.load_fixture("fixtures/advanced_F_body.txt"),
          cookies = h.load_fixture("fixtures/cookies.txt"),
        },
      }

      kulala.run_all()
      wait_for_requests(2)

      result = vim.json.decode(DB.data.current_request.body)
      assert.is_same("application/json", result.request_headers)
      assert.is_same("TEST_DOCUMENT_VAR", result.request_body)

      assert.is_same("TEST_JS_SET_REQUEST_VAR", result.response_body)
      assert.is_same("gunicorn/19.9.0", result.response_headers)
      assert.is_same("keep-alive", result.response_headers_1)
      assert.is_same("close", result.response_headers_2)
      assert.is_same("bar1", result.response_cookies)
    end)

    it("makes named requests, prompts for vars, uses scripts, uses env json", function()
      vim.cmd.edit(h.expand_path("requests/advanced_E.http"))

      input.stub { ["PROMPT_VAR prompt"] = "TEST_PROMPT_VAR" }
      curl.stub {
        ["*"] = {
          headers = h.load_fixture("fixtures/advanced_E_headers.txt"),
        },
        ["https://httpbin.org/advanced_e1"] = {
          body = h.load_fixture("fixtures/advanced_E1_body.txt"),
        },
        ["https://httpbin.org/advanced_e2"] = {
          body = h.load_fixture("fixtures/advanced_E2_body.txt"),
        },
        ["https://httpbin.org/advanced_e3"] = {
          body = h.load_fixture("fixtures/advanced_E3_body.txt"),
        },
      }

      kulala.run_all()
      wait_for_requests(3)

      local expected_request = h.load_fixture("fixtures/advanced_E3_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_E3_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(3, curl.requests_no)
      assert.has_string(result, expected)
    end)

    it("skips request conditionally", function()
      kulala_config.halt_on_error = false
      curl.stub { ["*"] = { body = '{ "foo": "bar" }' } }

      h.create_buf(
        ([[
          < {%
            if (!request.variables.get("Token")) {
               request.skip();
            }
          %}
          GET http://localhost:3001/request_1

          ###

          GET http://localhost:3001/request_2
      ]]):to_table(true),
        "test.http"
      )

      kulala.run_all()
      wait_for_requests(1)

      expected = DB.data.current_request.url

      assert.is_same(1, curl.requests_no)
      assert.is_same("http://localhost:3001/request_2", expected)
    end)

    it("replays request conditionally", function()
      curl.stub {
        ["http://localhost:3001/request_1"] = { headers = "HTTP/2 500" },
        ["http://localhost:3001/request_2"] = { headers = "HTTP/2 200" },
      }

      h.create_buf(
        ([[
          < {%
            if (!request.variables.get("URL")) { request.variables.set("URL", "request_1"); }
          %}
          GET http://localhost:3001/{{URL}}

          > {%
            if (response.responseCode === 500) {
              request.variables.set("URL", "request_2");
              request.replay();
            }
          %}
      ]]):to_table(true),
        "test.http"
      )

      kulala.run()
      wait_for_requests(2)
      assert.is_same(2, curl.requests_no)
    end)

    it("shows chunks as they arrive", function()
      local lines = h.to_table(
        [[
        # @accept chunked
        GET http://localhost:3001/chunked
      ]],
        true
      )

      local last_result = "none"
      local assert_chunk = function(system, errors, chunk, expected)
        curl.stub { ["*"] = { body = chunk } }
        curl.request(system)

        system.args.opts.stderr(_, errors)

        vim.wait(1000, function()
          ui_buf = h.get_kulala_buf()
          return result ~= last_result
        end)

        result = ui_buf ~= -1 and h.get_buf_lines(ui_buf):to_string() or ""
        assert.has_string(result, expected)

        last_result = result
      end

      system.stub({ "curl" }, {
        on_call = function(system)
          if vim.tbl_contains(system.args.cmd, "-N") then
            assert_chunk(system, "Waiting..", "Waiting..", "")
            assert_chunk(system, "Connected..", "Body 1", "Body 1")
            assert_chunk(system, "Connected..", "Body 1 Body 2", "Body 1 Body 2")
          end
        end,
      })

      h.create_buf(lines, "test.http")
      kulala.run_all()

      system:wait(3000, function()
        ui_buf = h.get_kulala_buf()
        return curl.requests_no == 3
      end)

      local curl_cmd = DB.data.current_request.cmd
      assert.is_true(vim.tbl_contains(curl_cmd, "-N"))

      expected = "Body 1 Body 2"
      result = h.get_buf_lines(ui_buf):to_string()

      assert.has_string(result, expected)
    end)

    it("does not show big size responses", function()
      curl.stub {
        ["https://httpbin.org/big_response"] = {
          body = "BIG SIZE RESPONSE",
        },
      }

      h.create_buf(
        ([[
          POST https://httpbin.org/big_response
      ]]):to_table(true),
        "test.http"
      )

      stub(vim.fn, "getfsize", function()
        return 65536 -- 64Kb
      end)

      kulala.run()
      wait_for_requests(1)

      vim.fn.getfsize:revert()

      expected = "The size of response is > 32Kb.\nPath to response: " .. GLOBALS.BODY_FILE
      result = h.get_buf_lines(ui_buf):to_string()

      assert.has_string(result, expected)
    end)

    it("downloads GraphQL schema", function()
      curl.stub {
        ["https://countries.trevorblades.com"] = {
          body = h.load_fixture("fixtures/graphql_schema_body.txt"),
        },
      }

      h.create_buf(
        ([[
          ### Countries

          POST https://countries.trevorblades.com
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
        "test.http"
      )

      vim.fn.setpos(".", { 0, 2, 1 })
      kulala.download_graphql_schema()

      system:wait(2000, function()
        return curl.requests_no == 1
      end)

      local request_cmd = system.args.cmd
      assert.is_true(vim.tbl_contains(request_cmd, function(flag)
        return flag:find("IntrospectionQuery")
      end, { predicate = true }))

      expected = h.load_fixture("fixtures/graphql_schema_body.txt")
      result = h.load_fixture(vim.uv.cwd() .. "/countries.trevorblades.com.graphql-schema.json")

      assert.has_string(result, expected)
    end)

    it("parses GraphQL request", function()
      curl.stub {
        ["https://countries.trevorblades.com"] = {
          body = h.load_fixture("fixtures/graphql_schema_body.txt"),
        },
      }

      h.create_buf(
        ([[
          POST https://countries.trevorblades.com
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
        "test.http"
      )

      kulala.run()
      wait_for_requests(1)

      local request_body_computed = DB.data.current_request.body_computed

      assert.has_string(request_body_computed, '"query":"query Person($id: ID) { person(personID: $id) { name } }')
      assert.has_string(request_body_computed, '"variables":{"id":1}')
    end)

    it("runs GraphQL request method", function()
      curl.stub {
        ["https://countries.trevorblades.com"] = {
          body = h.load_fixture("fixtures/graphql_schema_body.txt"),
        },
      }

      h.create_buf(
        ([[
          GRAPHQL https://countries.trevorblades.com

          query Person($id: ID) {
            person(personID: $id) {
              name
            }
          }

          {
            "id": 1
          }
      ]]):to_table(true),
        "test.http"
      )

      kulala.run()
      wait_for_requests(1)

      local request = DB.data.current_request

      assert.is_same("POST", request.method)
      assert.has_properties(request.headers, {
        ["Content-Type"] = "application/json",
      })

      assert.has_string(request.body_computed, '"query":"query Person($id: ID) { person(personID: $id) { name } }')
      assert.has_string(request.body_computed, '"variables":{"id":1}')
    end)

    it("runs API callbacks", function()
      curl.stub {
        ["https://httpbin.org/simple"] = {
          body = h.load_fixture("fixtures/simple_body.txt"),
        },
      }

      h.create_buf(([[ GET https://httpbin.org/simple ]]):to_table(true), "test.http")
      local cb_result = ""

      require("kulala.api").on("after_request", function(response)
        cb_result = cb_result .. "#After 1"
        expected = response.response
      end)

      local expected_2
      require("kulala.api").on("after_next_request", function(response)
        cb_result = cb_result .. "#After next"
        expected_2 = response.response
      end)

      kulala.run()
      wait_for_requests(1)

      assert.has_string(cb_result, "#After 1")
      assert.has_string(cb_result, "#After next")

      assert.has_string(expected.body, '"foo": "bar"')
      assert.has_string(expected_2.url, "https://httpbin.org/simple")

      cb_result = ""
      kulala.run()
      wait_for_requests(2)

      assert.has_string(cb_result, "#After 1")
      assert.is_not.has_string(cb_result, "#After next")
    end)

    describe("it runs lua scripts", function()
      it("runs inline scripts", function()
        curl.stub { ["*"] = { body = "{}" } }

        h.create_buf(
          ([[
          < {%
            -- lua
            client.global.Global = "global"
            request.environment.Foo = "foo"
          %}

          GET https://httpbin.org/{{Global}}/{{Foo}}

          > {%
            -- lua
            request.environment.Foo = "bar"
            client.global.Global = "new global"
          %}
      ]]):to_table(true),
          "test.http"
        )

        kulala.run()
        wait_for_requests(1)

        result = DB.data.current_request

        assert.is_same("https://httpbin.org/global/foo", curl.requests[1])
        assert.is_same("bar", result.environment.Foo)
        assert.is_same("new global", result.environment.Global)
      end)

      it("runs file scripts", function()
        curl.stub { ["*"] = { body = "{}" } }

        h.create_buf(
          ([[
          < ../scripts/pre_script.lua

          GET https://httpbin.org/{{Sky}}/{{Grass}}

          > ../scripts/post_script.lua
      ]]):to_table(true),
          h.expand_path("requests/simple.http")
        )

        kulala.run()
        wait_for_requests(1)

        result = DB.data.current_request

        assert.is_same("https://httpbin.org/Blue/Green", curl.requests[1])
        assert.is_same("Grey", result.environment.Sky)
        assert.is_same("Yellow", result.environment.Grass)
      end)
    end)

    describe("it halts on errors", function()
      before_each(function()
        DB.global_data.responses = {}
        kulala_config.halt_on_error = true
        kulala_config.debug = true

        curl.reset()
        curl.stub {
          ["https://request_2"] = {
            body = h.load_fixture("fixtures/request_1_body.txt"),
          },
        }

        h.create_buf(
          ([[
          POST https://request_2
          ###
          POST https://request_1
          ###
          POST https://request_2

      ]]):to_table(true),
          "test.http"
        )
      end)

      it("it halts on command error", function()
        curl.stub {
          ["https://request_1"] = {
            code = 124,
          },
        }

        kulala.run_all()
        wait_for_requests(2)

        result = h.get_buf_lines(ui_buf):to_string()
        assert.has_string(result, "Request: 2/2")
        assert.has_string(result, "Code: 124")
      end)

      it("it halts on response error", function()
        kulala_config.halt_on_error = true

        curl.stub {
          ["https://request_1"] = {
            stats = '{ "response_code": 500 }',
          },
        }

        kulala.run_all()
        wait_for_requests(2)

        result = h.get_buf_lines(ui_buf):to_string()
        assert.has_string(result, "Request: 2/2")
        assert.has_string(result, "Status: 500")
      end)

      it("it halts on assert error", function()
        kulala_config.halt_on_error = true

        curl.stub {
          ["https://request_1"] = {
            boby = '{ "data": { "foo": "baz" } }',
          },
        }

        h.delete_all_bufs()
        h.create_buf(
          ([[
          POST https://request_2
          ###
          POST https://request_1

          > {%

            assert.jsonHas("data.foo", "bar", "Check json");

          %}

          ###
          POST https://request_2

      ]]):to_table(true),
          "test.http"
        )

        kulala.run_all()
        wait_for_requests(2)

        result = h.get_buf_lines(ui_buf):to_string()
        assert.has_string(result, "Request: 2/2")
        assert.has_string(result, "Assert: failed")
      end)
    end)
  end)
end)
