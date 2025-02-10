---@diagnostic disable: undefined-field, redefined-local
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local KEYMAPS = require("kulala.config.keymaps")
local DB = require("kulala.db")
local kulala = require("kulala")

local kulala_name = GLOBALS.UI_ID
local kulala_config = CONFIG.options

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")

describe("UI", function()
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

    it("for current line in in non-http buffer and strips comments chars", function()
      kulala_config.default_view = "body"

      curl.stub({
        ["https://httpbin.org/advanced_1"] = {
          body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
        },
      })

      h.create_buf(
        ([[
          -- @foobar=bar
          ;; @ENV_PROJECT = project_name
          
          #- POST https://httpbin.org/advanced_1 HTTP/1.1
          /*-- Content-Type: application/json
        ]]):to_table(),
        "test.lua"
      )

      h.send_keys("3j")
      kulala.run()
      wait_for_requests(1)

      local cmd = DB.data.current_request.cmd
      assert.is_same("https://httpbin.org/advanced_1", cmd[#cmd])
    end)

    it("for current selection in in non-http buffer", function()
      kulala_config.default_view = "body"

      curl.stub({
        ["https://httpbin.org/advanced_1"] = {
          body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
        },
      })

      h.create_buf(
        ([[
          Some text
          Some text

        //###

          -- @foobar=bar
          ##@ENV_PROJECT = project_name

          ;# @accept chunked
          /* POST https://httpbin.org/advanced_1 HTTP/1.1
          #  Content-Type: application/json

        // {
        (*   "project": "{{ENV_PROJECT}}",
        ;;     "results": [
             {
        ;;       "id": 1,
        ;;       "desc": "{{foobar}}"
             },
             ]
        ;; }
          > {%
          client.log("TEST LOG")
          %}
        ]]):to_table(true),
        "test.lua"
      )

      h.send_keys("3jV20j")

      kulala.run()
      wait_for_requests(1)

      local cmd = DB.data.current_request.cmd
      assert.is_same("https://httpbin.org/advanced_1", cmd[#cmd])

      local computed_body = DB.data.current_request.body_computed
      local expected_computed_body =
        '{\r\n"project": "project_name",\r\n"results": [\r\n{\r\n"id": 1,\r\n"desc": "bar"\r\n},\r\n]\r\n}'

      assert.is_same(expected_computed_body, computed_body)
      assert.is_true(notify.has_message("TEST LOG"))
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

    --FIX: last replay - save to file again before run
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

      expected = "curl -X 'GET' -v -s -A 'kulala.nvim/" .. GLOBALS.VERSION .. "' 'http://localhost:3001/request_1'"
      result = vim.fn.getreg("+")
      assert.are.same(expected, result)
    end)
  end)

  describe("keymaps", function()
    local global_keymaps = KEYMAPS.default_global_keymaps
    local kulala_keymaps = KEYMAPS.default_kulala_keymaps
    local keymaps_n, keymaps_v

    vim.g.mapleader = ","

    before_each(function()
      h.delete_all_maps()
    end)

    describe("global keymaps", function()
      before_each(function()
        CONFIG.setup({
          global_keymaps = {
            ["Inspect current request"] = {
              "<leader>RI",
              function() end,
            },
            ["Open scratchpad"] = false,
          },
        })

        keymaps_n = vim.tbl_keys(h.get_maps())
        keymaps_v = vim.tbl_keys(h.get_maps(nil, "v"))
      end)

      it("sets default keymaps", function()
        http_buf = h.create_buf(lines, "test.txt")

        expected = global_keymaps["Open kulala"][1]
        assert.is_true(vim.tbl_contains(keymaps_n, expected))

        expected = global_keymaps["Send request"][1]
        assert.is_true(vim.tbl_contains(keymaps_v, expected))

        expected = global_keymaps["Jump to next request"][1]
        assert.is_false(vim.tbl_contains(keymaps_n, expected))
      end)

      it("sets filetype keymaps", function()
        vim.cmd.e("test.http")
        keymaps_n = vim.tbl_keys(h.get_maps(http_buf))

        expected = global_keymaps["Find request"][1]
        assert.is_true(vim.tbl_contains(keymaps_n, expected))
      end)

      it("sets and disables custom keymaps", function()
        expected = "<leader>RI"
        assert.is_true(vim.tbl_contains(keymaps_n, expected))
        assert.is_false(vim.tbl_contains(keymaps_n, global_keymaps["Open scratchpad"][1]))
      end)
    end)

    describe("global keymaps", function()
      it("disables default keymaps", function()
        CONFIG.setup({ global_keymaps = false })

        local keymaps_n = vim.tbl_keys(h.get_maps())
        expected = global_keymaps["Open kulala"][1]
        assert.is_false(vim.tbl_contains(keymaps_n, expected))
      end)
    end)

    describe("local keymaps", function()
      before_each(function()
        s.Fs:stub_read_file({ [GLOBALS.BODY_FILE] = h.load_fixture("fixtures/request_2_headers_body.txt") })

        CONFIG.setup({
          default_view = "body",
          kulala_keymaps = {
            ["Show headers"] = {
              "HH",
              function() end,
            },
            ["Show headers and body"] = false,
          },
        })

        kulala.open()
        ui_buf = vim.fn.bufnr(kulala_name)

        keymaps_n = vim.tbl_keys(h.get_maps(ui_buf))
      end)

      after_each(function()
        kulala.close()
        s.Fs:read_file_reset()
      end)

      it("sets default keymaps", function()
        expected = kulala_keymaps["Show body"][1]
        assert.is_true(vim.tbl_contains(keymaps_n, expected))
      end)

      it("sets custom keymaps", function()
        assert.is_true(vim.tbl_contains(keymaps_n, "HH"))

        expected = kulala_keymaps["Show headers and body"][1]
        assert.is_false(vim.tbl_contains(keymaps_n, expected))
      end)

      it("disbales default keymaps", function()
        kulala.close()
        CONFIG.setup({ kulala_keymaps = false })

        kulala.open()
        ui_buf = vim.fn.bufnr(kulala_name)

        keymaps_n = vim.tbl_keys(h.get_maps(ui_buf))

        expected = kulala_keymaps["Show body"][1]
        assert.is_false(vim.tbl_contains(keymaps_n, expected))
      end)
    end)
  end)
end)
