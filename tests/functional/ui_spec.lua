---@diagnostic disable: undefined-field, redefined-local
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local kulala = require("kulala")

local kulala_name = GLOBALS.UI_ID

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")

--TODO: float/split/close

describe("requests", function()
  describe("show output of requests", function()
    local curl, system, wait_for_requests
    local input, notify, dynamic_vars
    local lines, result, expected, http_buf, ui_buf

    before_each(function()
      h.delete_all_bufs()

      input = s.Input.stub()
      notify = s.Notify.stub()
      dynamic_vars = s.Dynamic_vars.stub()

      curl = s.Curl.stub({
        ["*"] = {
          stats = h.load_fixture("fixtures/stats.json"),
        },
        ["http://localhost:3001/request_1"] = {
          headers = h.load_fixture("fixtures/request_1_headers.txt"),
          body = h.load_fixture("fixtures/request_1_body.txt"),
          errors = h.load_fixture("fixtures/request_1_errors.txt"),
        },
        ["http://localhost:3001/request_2"] = {
          headers = h.load_fixture("fixtures/request_2_headers.txt"),
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

      lines = h.to_table(
        [[
        GET http://localhost:3001/request_1

        ###

        GET http://localhost:3001/request_2
      ]],
        true
      )

      http_buf = h.create_buf(lines, "test.http")
      CONFIG.options.display_mode = "float"
    end)

    after_each(function()
      h.delete_all_bufs()
      curl.reset()
      system.reset()
      input.reset()
      notify.reset()
      dynamic_vars.reset()
    end)

    it("shows request output ineaders headers mode", function()
      CONFIG.options.default_view = "headers"

      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_headers.txt")

      assert.is_same(expected, result)
    end)

    it("shows request output in body mode", function()
      CONFIG.options.default_view = "body"

      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_body.txt")

      assert.is_same(expected, result)
    end)

    it("shows request output in body mode on selected line", function()
      CONFIG.options.default_view = "body"

      vim.fn.setpos(".", { 0, 5, 0, 0 })
      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_2_body.txt")

      assert.is_same(expected, result)
    end)

    it("shows last request output in body_headers mode for run_all", function()
      CONFIG.options.default_view = "headers_body"

      kulala.run_all()
      wait_for_requests(2)

      expected = h.load_fixture("fixtures/request_2_headers_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.is_same(expected, result)
    end)

    it("shows request output in verbose mode", function()
      CONFIG.options.default_view = "verbose"

      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_verbose.txt")

      assert.is_same(expected, result)
    end)

    it("shows last request output in verbose mode for run_all", function()
      CONFIG.options.default_view = "verbose"

      kulala.run_all()
      wait_for_requests(2)

      expected = h.load_fixture("fixtures/request_2_verbose.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.is_same(expected, result)
    end)

    it("shows last request output in verbose mode", function()
      CONFIG.options.default_view = "stats"

      kulala.run()
      wait_for_requests(1)

      expected = h.load_fixture("fixtures/request_1_stats.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected, result)
    end)

    it("shows last request output in script mode", function()
      CONFIG.options.default_view = "script_output"

      h.set_buf_lines(
        http_buf,
        ([[
          GET http://localhost:3001/request_1

          > {%
          client.log(response.headers.valuesOf("Date").value);
          client.log("JS: TEST");
          %}
      ]]):to_table(true)
      )

      kulala.run()
      wait_for_requests(1)

      expected = h.load_fixture("fixtures/request_1_script.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected, result)
    end)

    it("inspect window", function()
      CONFIG.options.default_view = "body"

      h.set_buf_lines(
        http_buf,
        ([[
          @foobar=bar
          @ENV_PROJECT = project_name

          POST https://httpbin.org/post HTTP/1.1
          Content-Type: application/json

          {
            "project": "{{ENV_PROJECT}}",
              "results": [
              {
                "id": 1,
                "desc": "{{foobar}}"
              },
              ]
          }]]):to_table(true)
      )

      kulala.inspect()
      ui_buf = vim.fn.bufnr("kulala://inspect")

      expected = ([[
        POST https://httpbin.org/post HTTP/1.1
        Content-Type: application/json

        {
          "project": "project_name",
            "results": [
            {
              "id": 1,
              "desc": "bar"
            },
            ]
        }]]):to_string(true)

      result = h.get_buf_lines(ui_buf):to_string()
      assert.is_same(expected, result)
    end)
  end)
end)
