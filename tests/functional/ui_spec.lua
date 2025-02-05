---@diagnostic disable: undefined-field, redefined-local
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local kulala = require("kulala")

local kulala_name = GLOBALS.UI_ID
local kulala_config = CONFIG.options

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")

describe("requests", function()
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
        return curl.requests_no >= requests_no and ui_buf > 0
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
    kulala_config.display_mode = "float"
  end)

  after_each(function()
    h.delete_all_bufs()
    curl.reset()
    system.reset()
    input.reset()
    notify.reset()
    dynamic_vars.reset()
  end)

  describe("show output of requests", function()
    it("in headers mode", function()
      kulala_config.default_view = "headers"

      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_headers.txt")

      assert.is_same(expected, result)
    end)

    it("in body mode", function()
      kulala_config.default_view = "body"

      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_body.txt")

      assert.is_same(expected, result)
    end)

    it("for current line in body mode", function()
      kulala_config.default_view = "body"

      vim.fn.setpos(".", { 0, 5, 0, 0 })
      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_2_body.txt")

      assert.is_same(expected, result)
    end)

    it("last request in body_headers mode for run_all", function()
      kulala_config.default_view = "headers_body"

      kulala.run_all()
      wait_for_requests(2)

      expected = h.load_fixture("fixtures/request_2_headers_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.is_same(expected, result)
    end)

    it("in verbose mode", function()
      kulala_config.default_view = "verbose"

      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_verbose.txt")

      assert.is_same(expected, result)
    end)

    it("in verbose mode for run_all", function()
      kulala_config.default_view = "verbose"

      kulala.run_all()
      wait_for_requests(2)

      expected = h.load_fixture("fixtures/request_2_verbose.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.is_same(expected, result)
    end)

    it("stats of the request", function()
      kulala_config.default_view = "stats"

      kulala.run()
      wait_for_requests(1)

      expected = h.load_fixture("fixtures/request_1_stats.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(expected, result)
    end)

    it("in script mode", function()
      kulala_config.default_view = "script_output"

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

    it("replays last request", function()
      kulala_config.default_view = "body"

      kulala.run()
      wait_for_requests(1)

      h.delete_all_bufs()

      kulala.replay()
      wait_for_requests(2)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_body.txt")

      assert.is_same(expected, result)
    end)
  end)

  describe("UI features", function()
    it("opens results in split", function()
      kulala_config.default_view = "body"
      kulala_config.display_mode = "split"

      kulala.run()
      wait_for_requests(1)

      local win_config = vim.api.nvim_win_get_config(vim.fn.bufwinid(ui_buf))
      assert.is_same("right", win_config.split)
    end)

    it("opens results in float", function()
      kulala_config.default_view = "body"
      kulala_config.display_mode = "float"

      kulala.run()
      wait_for_requests(1)

      local win_config = vim.api.nvim_win_get_config(vim.fn.bufwinid(ui_buf))
      assert.is_same("editor", win_config.relative)
    end)

    it("closes float and deletes buffer on 'q'", function()
      kulala_config.default_view = "body"
      kulala_config.display_mode = "float"
      kulala_config.q_to_close_float = true

      kulala.run()
      wait_for_requests(1)

      h.send_keys("q")
      assert.is_false(vim.fn.bufexists(ui_buf) > 0)
    end)

    it("closes ui and current buffer if it is *.http|rest", function()
      kulala_config.default_view = "body"
      kulala_config.display_mode = "float"
      kulala_config.q_to_close_float = true

      kulala.run()
      wait_for_requests(1)
      kulala.close()

      assert.is_false(vim.fn.bufexists(http_buf) > 0)
      assert.is_false(vim.fn.bufexists(ui_buf) > 0)
    end)

    it("shows inspect window", function()
      kulala_config.default_view = "body"

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

    it("pastes simple curl", function()
      vim.fn.setreg("+", "curl http://example.com")
      h.set_buf_lines(http_buf, {})

      kulala.from_curl()

      expected = ([[# curl http://example.com
          GET http://example.com

        ]]):to_string(true)

      result = h.get_buf_lines(http_buf):to_string()
      assert.are.same(expected, result)
    end)

    it("copies curl command", function()
      kulala.copy()

      expected = "curl -X 'GET' -v -s -A 'kulala.nvim/4.8.0' 'http://localhost:3001/request_1'"
      result = vim.fn.getreg("+")
      assert.are.same(expected, result)
    end)
  end)
end)
