---@diagnostic disable: undefined-field, redefined-local
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local kulala = require("kulala")

local kulala_name = GLOBALS.UI_ID
local kulala_config = CONFIG.options

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")
assert.is_true(vim.fn.executable("npm") == 1)

describe("requests", function()
  describe("show output of requests", function()
    local curl, system, wait_for_requests
    local input, notify, dynamic_vars
    local result, expected, ui_buf

    before_each(function()
      h.delete_all_bufs()

      input = s.Input.stub()
      notify = s.Notify.stub()
      dynamic_vars = s.Dynamic_vars.stub()

      curl = s.Curl.stub({
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
      })

      system = s.System.stub({ "curl" }, {
        on_call = function(system)
          curl.request(system)
        end,
      })

      wait_for_requests = function(requests_no)
        system:wait(3000, function()
          ui_buf = vim.fn.bufnr(kulala_name)
          return curl.requests_no == requests_no and ui_buf > 0
        end)
      end

      kulala_config.default_view = "body"
    end)

    after_each(function()
      h.delete_all_bufs()
      curl.reset()
      system.reset()
      input.reset()
      notify.reset()
      dynamic_vars.reset()
    end)

    it("it substitues document variables and does authorization", function()
      vim.cmd.edit(h.expand_path("requests/simple.http"))

      curl.stub({
        ["https://httpbin.org/simple"] = {
          body = h.load_fixture("fixtures/simple_body.txt"),
        },
      })

      kulala.run()
      wait_for_requests(1)

      local expected_request = h.load_fixture("fixtures/simple_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/simple_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.headers, computed_request.headers)
      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(expected, result)
    end)

    it("sets env variable with @env-stdin-cmd", function()
      vim.cmd.edit(h.expand_path("requests/chain.http"))

      curl.stub({
        ["https://httpbin.org/chain_1"] = {
          body = h.load_fixture("fixtures/chain_1_body.txt"),
        },
        ["https://httpbin.org/chain_2"] = {
          body = h.load_fixture("fixtures/chain_2_body.txt"),
        },
      })

      kulala.run_all()
      wait_for_requests(2)

      local expected_request = h.load_fixture("fixtures/chain_2_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/chain_2_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(2, curl.requests_no)
      assert.is_same(expected, result)
    end)

    it("sets environment variables from response", function()
      vim.cmd.edit(h.expand_path("requests/advanced_A.http"))

      curl.stub({
        ["https://httpbin.org/advanced_1"] = {
          body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
        },
        ["https://httpbin.org/advanced_2"] = {
          body = h.load_fixture("fixtures/advanced_A_2_body.txt"),
        },
      })

      kulala.run_all()
      wait_for_requests(2)

      local expected_request = h.load_fixture("fixtures/advanced_A_2_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_A_2_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(2, curl.requests_no)
      assert.is_same(result, expected)
    end)

    it("substitutes http.client.json variables, accesses request/response from js and logs to client", function()
      vim.cmd.edit(h.expand_path("requests/advanced_B.http"))

      curl.stub({
        ["https://httpbin.org/advanced_b"] = {
          body = h.load_fixture("fixtures/advanced_B_body.txt"),
        },
      })

      kulala.run_all()
      wait_for_requests(1)

      local expected_request = h.load_fixture("fixtures/advanced_B_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_B_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.headers, computed_request.headers)
      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(result, expected)
      assert.is_true(notify.has_message("Foobar"))
      assert.is_true(notify.has_message("Thu, 30 Jan 2025 16:21:56 GMT"))
    end)

    it("load a file with @file-to-variable", function()
      vim.cmd.edit(h.expand_path("requests/advanced_C.http"))

      dynamic_vars.stub({ ["$timestamp"] = "$TIMESTAMP" })
      curl.stub({
        ["https://httpbin.org/advanced_c"] = {
          body = h.load_fixture("fixtures/advanced_C_body.txt"),
        },
      })

      kulala.run_all()
      wait_for_requests(1)

      local expected_request = h.load_fixture("fixtures/advanced_C_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_C_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(result, expected)
    end)

    it("prompts for vars, computes request vars, logs to client", function()
      vim.cmd.edit(h.expand_path("requests/advanced_D.http"))

      input.stub({ ["Password prompt"] = "TEST_PASSWORD" })
      curl.stub({
        ["https://httpbin.org/advanced_d"] = {
          body = h.load_fixture("fixtures/advanced_D_body.txt"),
        },
      })

      kulala.run_all()
      wait_for_requests(1)

      local expected_request = h.load_fixture("fixtures/advanced_D_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_D_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(computed_request.headers, expected_request.headers)
      assert.is_same(computed_request.body_computed, expected_request.body_computed)
      assert.is_true(notify.has_message("Content-Type:application/json"))
      assert.is_true(notify.has_message("{ someHeaderValue: { name: 'Server', value: 'gunicorn/19.9.0' } }"))
      assert.is_same(expected, result)
    end)

    it("makes named requests, prompts for vars, uses scripts, uses env json", function()
      vim.cmd.edit(h.expand_path("requests/advanced_E.http"))

      input.stub({ ["PROMPT_VAR prompt"] = "TEST_PROMPT_VAR" })
      curl.stub({
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
      })

      kulala.run_all()
      wait_for_requests(3)

      local expected_request = h.load_fixture("fixtures/advanced_E3_request.txt"):to_object().current_request
      local computed_request = DB.data.current_request

      expected = h.load_fixture("fixtures/advanced_E3_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected_request.body_computed, computed_request.body_computed)
      assert.is_same(3, curl.requests_no)
      assert.is_same(expected, result)
    end)

    it("shows chunks as they arrive", function()
      local lines = h.to_table(
        [[
        # @accept chunked
        GET http://localhost:3001/chunked
      ]],
        true
      )

      local last_buf = -1
      local assert_chunk = function(system, errors, chunk, expected)
        curl.stub({ ["*"] = { body = chunk } })
        curl.request(system)

        system.args.opts.stderr(_, errors)

        vim.wait(1000, function()
          ui_buf = vim.fn.bufnr(kulala_name)
          return ui_buf ~= last_buf
        end)

        result = ui_buf ~= -1 and h.get_buf_lines(ui_buf):to_string() or nil
        assert.is_same(expected, result)

        last_buf = ui_buf
      end

      system.stub({ "curl" }, {
        on_call = function(system)
          if vim.tbl_contains(system.args.cmd, "-N") then
            assert_chunk(system, "Waiting..", "Waiting..", nil)
            assert_chunk(system, "Connected..", "Body 1", "Body 1")
            assert_chunk(system, "Connected..", "Body 1 Body 2", "Body 1 Body 2")
          end
        end,
      })

      h.create_buf(lines, "test.http")
      kulala.run_all()

      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(kulala_name)
        return curl.requests_no == 3
      end)

      local curl_cmd = DB.data.current_request.cmd
      assert.is_true(vim.tbl_contains(curl_cmd, "-N"))

      expected = "Body 1 Body 2"
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected, result)
      assert.is_true(ui_buf ~= last_buf)
    end)

    it("downloads GraphQL schema", function()
      curl.stub({
        ["https://countries.trevorblades.com"] = {
          body = h.load_fixture("fixtures/graphql_schema_body.txt"),
        },
      })

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

      kulala.download_graphql_schema()

      system:wait(2000, function()
        return curl.requests_no == 1
      end)

      local request_cmd = system.args.cmd
      assert.is_true(vim.tbl_contains(request_cmd, function(flag)
        return flag:find("IntrospectionQuery")
      end, { predicate = true }))

      expected = h.load_fixture("fixtures/graphql_schema_body.txt")
      result = h.load_fixture(vim.uv.cwd() .. "/test.graphql-schema.json")

      assert.is_same(expected, result)
    end)

    it("parses GraphQL request", function()
      curl.stub({
        ["POST https://countries.trevorblades.com"] = {
          body = h.load_fixture("fixtures/graphql_schema_body.txt"),
        },
      })

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

      local expected_body_computed =
        '{"variables":{"id":1},"query":"query Person($id: ID) { person(personID: $id) { name } } "}'
      local request_body_computed = DB.data.current_request.body_computed

      assert.is_same(expected_body_computed, request_body_computed)
    end)
  end)

  describe("parse body", function()
    -- \r\n
    -- multipart
    -- < include
    -- {file-to-var}
  end)
end)
