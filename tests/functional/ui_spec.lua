---@diagnostic disable: undefined-field, redefined-local
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local GLOBALS = require("kulala.globals")
local kulala = require("kulala")
local ui = require("kulala.ui")

local kulala_name = GLOBALS.UI_ID
local kulala_config

local h = require("test_helper")

describe("UI", function()
  local curl, system, wait_for_requests
  local input, output, notify, dynamic_vars
  local lines, result, expected, http_buf, ui_buf

  before_each(function()
    h.delete_all_bufs()

    input = h.Input.stub()
    output = h.Output.stub()
    notify = h.Notify.stub()
    dynamic_vars = h.Dynamic_vars.stub()

    curl = h.Curl.stub {
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
    }

    system = h.System.stub({ "curl" }, {
      on_call = function(system)
        curl.request(system)
      end,
    })

    wait_for_requests = function(requests_no, predicate)
      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(kulala_name)
        return curl.requests_no >= requests_no and ui_buf > 0 and (predicate == nil or predicate())
      end)
    end

    kulala_config = CONFIG.setup {
      global_keymaps = true,
      ui = {
        default_view = "body",
        display_mode = "float",
        show_request_summary = true,
      },
    }

    lines = h.to_table(
      [[
        GET http://localhost:3001/request_1

        ###

        GET http://localhost:3001/request_2
      ]],
      true
    )

    http_buf = h.create_buf(lines, "test.http")
  end)

  after_each(function()
    h.delete_all_bufs()
    curl.reset()
    system.reset()
    input.reset()
    output.reset()
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

      assert.has_string(result, expected)
    end)

    it("in body mode", function()
      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_body.txt")

      assert.has_string(result, expected)
    end)

    it("shows summary of request", function()
      local db = DB.global_update()
      db.responses = {}
      db.current_response_pos = 1

      vim.uv.os_setenv("TZ", "UTC")

      ---@diagnostic disable-next-line: missing-fields
      table.insert(db.responses, {
        status = true,
        code = 0,
        response_code = 200,
        assert_status = false,
        duration = 3250000,
        time = 1740826092,
        url = "http://example.com",
        method = "GET",
        line = 15,
        buf_name = "test.txt",
        name = "Request 1",
        body = h.load_fixture("fixtures/request_2_headers_body.txt"),
        headers = "",
      })

      kulala.open()
      result = h.get_buf_lines(h.get_kulala_buf()):to_string()

      assert.has_string(result, "Request: " .. #db.responses .. "/" .. #db.responses)
      assert.has_string(result, "Code: 0")
      assert.has_string(result, "Status: 200")
      assert.has_string(result, "Assert: failed")
      assert.has_string(result, "Duration: 3.25 ms")
      assert.has_string(result, "Time: Mar 01 10:48:12")
      assert.has_string(result, "URL: GET http://example.com")
      assert.has_string(result, "Buffer: test.txt::15")
    end)

    it("for current line in body mode", function()
      vim.fn.setpos(".", { 0, 5, 0, 0 })
      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_2_body.txt")

      assert.has_string(result, expected)
    end)

    it("for current line in in non-http buffer and strips comments chars", function()
      curl.stub {
        ["https://httpbin.org/advanced_1"] = {
          body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
        },
      }

      h.create_buf(
        ([[
          -- @foobar=bar
          ;; @ENV_PROJECT = project_name
          
          ## POST https://httpbin.org/advanced_1 HTTP/1.1
          /* Content-Type: application/json
        ]]):to_table(true),
        "test.lua"
      )

      h.send_keys("3j")
      kulala.run()
      wait_for_requests(1)

      local cmd = DB.data.current_request.cmd
      assert.is_same("https://httpbin.org/advanced_1", cmd[#cmd])
    end)

    it("for current selection in in non-http buffer", function()
      curl.stub {
        ["https://httpbin.org/advanced_1"] = {
          body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
        },
      }

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
      local expected_computed_body = '{\n"project": "project_name",\n"results": [\n{\n"id": 1,\n"desc": "bar"\n},\n]\n}'

      assert.is_same(expected_computed_body, computed_body)
      assert.has_string(output.log, "TEST LOG")
    end)

    it("last request in body_headers mode for run_all", function()
      kulala_config.default_view = "headers_body"

      kulala.run_all()
      wait_for_requests(2)

      expected = h.load_fixture("fixtures/request_2_headers_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.has_string(result, expected)
    end)

    it("in verbose mode", function()
      kulala_config.default_view = "verbose"

      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_verbose.txt")

      assert.has_string(result, expected)
    end)

    it("in verbose mode for run_all", function()
      kulala_config.default_view = "verbose"

      kulala.run_all()
      wait_for_requests(2)

      expected = h.load_fixture("fixtures/request_2_verbose.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.has_string(result, expected)
    end)

    it("in custom mode", function()
      kulala_config.default_view = function(response)
        result = response.body
      end

      kulala.run()
      wait_for_requests(1)

      assert.has_string(result, "Greeting")
    end)

    it("stats of the request", function()
      kulala_config.default_view = "stats"

      kulala.run()
      wait_for_requests(1)

      expected = h.load_fixture("fixtures/request_1_stats.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.has_string(result, expected)
    end)

    it("in script mode", function()
      kulala_config.default_view = "script_output"

      h.set_buf_lines(
        http_buf,
        ([[
          GET http://localhost:3001/request_1

          > {%
          client.log(response.headers.valueOf("Date"));
          client.log("JS: TEST");
          %}
      ]]):to_table(true)
      )

      kulala.run()
      wait_for_requests(1)

      expected = h.load_fixture("fixtures/request_1_script.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.has_string(result, expected)
    end)

    it("replays last request", function()
      kulala.run()
      wait_for_requests(1)

      h.delete_all_bufs()

      kulala.replay()
      wait_for_requests(2)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("fixtures/request_1_body.txt")

      assert.has_string(result, expected)
    end)

    it("updates jq filter", function()
      h.set_buf_lines(
        http_buf,
        ([[
          # @jq { "Content": .headers["Content-Type"], "url": .url }
          GET https://httpbin.org/simple
      ]]):to_table(true)
      )

      curl.stub {
        ["https://httpbin.org/simple"] = {
          body = h.load_fixture("fixtures/simple_body.txt"),
        },
      }

      kulala.run()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string()
      assert.has_string(result, 'JQ Filter: { "Content": .headers["Content-Type"], "url": .url }')

      vim.api.nvim_set_current_buf(ui_buf)
      vim.api.nvim_buf_set_lines(ui_buf, 4, 5, false, { 'JQ Filter: { "Content": .json.foo }' })

      vim.api.nvim_win_set_cursor(h.get_kulala_win(), { 5, 0 })
      ui.keymap_enter()

      result = h.get_buf_lines(ui_buf)
      assert.has_string(result, '"Content": "bar"')
    end)
  end)

  describe("history of responses", function()
    before_each(function()
      DB.global_update().responses = {}
      h.delete_all_bufs()

      input.stub { ["PROMPT_VAR prompt"] = "TEST_PROMPT_VAR" }
      curl.stub {
        ["https://httpbin.org/advanced_e1"] = {
          headers = h.load_fixture("fixtures/advanced_E_headers.txt"),
          body = h.load_fixture("fixtures/advanced_E1_body.txt"),
          errors = h.load_fixture("fixtures/request_1_errors.txt"),
        },
        ["https://httpbin.org/advanced_e2"] = {
          headers = h.load_fixture("fixtures/advanced_E_headers.txt"),
          body = h.load_fixture("fixtures/advanced_E2_body.txt"),
          stats = h.load_fixture("fixtures/stats.json"),
        },
        ["https://httpbin.org/advanced_e3"] = {
          headers = h.load_fixture("fixtures/request_2_headers.txt"),
          body = h.load_fixture("fixtures/advanced_E3_body.txt"),
          errors = h.load_fixture("fixtures/request_2_errors.txt"),
        },
      }
    end)

    it("stores responses of consecutive requests", function()
      vim.cmd.edit(h.expand_path("requests/advanced_E.http"))

      kulala.run_all()
      wait_for_requests(3)

      vim.api.nvim_set_current_buf(ui_buf)

      expected = h.load_fixture("fixtures/advanced_E3_body.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.has_string(result, "Request: 3/3")
      assert.has_string(result, "URL: POST https://httpbin.org/advanced_e3")
      assert.has_string(result, expected)

      h.send_keys("H")

      expected = h.load_fixture("fixtures/request_2_headers.txt")
      result = h.get_buf_lines(h.get_kulala_buf()):to_string()

      assert.has_string(result, "Request: 3/3")
      assert.has_string(result, expected)

      h.send_keys("V")

      expected = h.load_fixture("fixtures/request_2_errors_payload.txt")
      result = h.get_buf_lines(h.get_kulala_buf()):to_string()

      assert.has_string(result, "Request: 3/3")
      assert.has_string(result, expected)

      h.send_keys("[")
      h.send_keys("B")

      expected = h.load_fixture("fixtures/advanced_E2_body.txt")
      result = h.get_buf_lines(h.get_kulala_buf()):to_string()

      assert.has_string(result, "Request: 2/3")
      assert.has_string(result, "URL: POST https://httpbin.org/advanced_e2")
      assert.has_string(result, expected)
      --
      h.send_keys("S")

      expected = h.load_fixture("fixtures/request_1_stats.txt")
      result = h.get_buf_lines(h.get_kulala_buf()):to_string()

      assert.has_string(result, "Request: 2/3")
      assert.has_string(result, expected)

      h.send_keys("[")
      h.send_keys("B")

      expected = h.load_fixture("fixtures/advanced_E1_body.txt")
      result = h.get_buf_lines(h.get_kulala_buf()):to_string()

      assert.has_string(result, "Request: 1/3")
      assert.has_string(result, "URL: POST https://httpbin.org/advanced_e1")
      assert.has_string(result, expected)

      h.send_keys("O")

      result = h.get_buf_lines(h.get_kulala_buf()):to_string()

      assert.has_string(result, "Request: 1/3")
      assert.has_string(
        result,
        ([[
        ===== Pre Script Output =====================================

        JS: PRE TEST


        ===== Post Script Output ====================================

        JS: POST TEST
      ]]):to_string(true)
      )
    end)

    it("shows failed requests and errors", function()
      kulala_config.halt_on_error = false

      curl.stub {
        ["https://request_1"] = {
          boby = '{ "data": { "foo": "baz" } }',
          stats = '{"response_code": 500}',
          errors = "Curt error",
        },
      }

      h.create_buf(
        ([[
          POST https://request_1
          ###
          POST https://request_1
          ###
          POST https://request_2

      ]]):to_table(true),
        "test.http"
      )

      kulala.run_all()
      wait_for_requests(3)

      vim.api.nvim_set_current_buf(ui_buf)
      h.send_keys("[")

      result = h.get_buf_lines(ui_buf):to_string()

      h.has_highlight(ui_buf, 0, kulala_config.ui.report.error_highlight)
      expected = vim.bo[ui_buf].filetype

      assert.has_string(result, "Request: 2/3")
      assert.has_string(result, "Status: 500")
    end)

    it("it clears responses history", function()
      h.create_buf(
        ([[
          POST https://request_1
          ###
          POST https://request_1
          ###
          POST https://request_2

      ]]):to_table(true),
        "test.http"
      )

      kulala.run_all()
      wait_for_requests(3)

      vim.api.nvim_set_current_buf(ui_buf)
      h.send_keys("X")

      result = h.get_buf_lines(ui_buf):to_string()
      assert.has_string(result, "Request: 0/0")
    end)
  end)

  describe("UI features", function()
    it("opens results in split", function()
      kulala_config.display_mode = "split"

      kulala.run()
      wait_for_requests(1)

      local win_config = vim.api.nvim_win_get_config(vim.fn.bufwinid(ui_buf))
      assert.is_truthy(win_config.split)
    end)

    it("opens results in float", function()
      kulala.run()
      wait_for_requests(1)

      local win_config = vim.api.nvim_win_get_config(vim.fn.bufwinid(ui_buf))
      assert.is_truthy(win_config.relative)
    end)

    it("closes float and deletes buffer on 'q'", function()
      kulala_config.q_to_close_float = true

      kulala.run()
      wait_for_requests(1)

      vim.api.nvim_set_current_buf(ui_buf)
      h.send_keys("q")

      assert.is_false(vim.fn.bufexists(ui_buf) > 0)
    end)

    it("closes ui and current buffer if it is *.http|rest", function()
      kulala_config.q_to_close_float = true

      kulala.run()
      wait_for_requests(1)
      kulala.close()

      assert.is_false(vim.fn.bufexists(http_buf) > 0)
      assert.is_false(vim.fn.bufexists(ui_buf) > 0)
    end)

    it("shows inspect window", function()
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
      assert.has_string(result, expected)
    end)

    it("pastes curl command", function()
      vim.fn.setreg(
        "+",
        ([[curl -X 'POST' -v -s --data '{ "foo": "bar" }' -H 'Content-Type:application/json' -b 'cookie_key=value' --http1.1 -A 'kulala.nvim/4.10.0' 'https://httpbin.org/post']]):to_string(
          true
        )
      )
      h.set_buf_lines(http_buf, {})

      kulala.from_curl()

      expected = ([[
          # curl -X 'POST' -v -s --data '{ "foo": "bar" }' -H 'Content-Type:application/json' -b 'cookie_key=value' --http1.1 -A 'kulala.nvim/4.10.0' 'https://httpbin.org/post'
          POST https://httpbin.org/post HTTP/1.1
          content-type: application/json
          user-agent: kulala.nvim/4.10.0
          Cookie: cookie_key=value

          { "foo": "bar" }
        ]]):to_string(true)

      result = h.get_buf_lines(http_buf):to_string()
      assert.has_string(result, expected)
    end)

    it("copies curl command with body", function()
      h.create_buf(
        ([[
        POST http://localhost:3001/request_1
        Content-Type: application/json
        Cookie: cookie_key=value

        {
          "foo": "bar"
        }
      ]]):to_table(true),
        "test.rest"
      )

      kulala.copy()

      expected = vim.fn.has("win32") == 1
          and [[curl -X "POST" -v -s -H "Content-Type:application/json" --data-binary "{""foo"": ""bar""}" --cookie "cookie_key=value" -A "kulala.nvim/%s" "http://localhost:3001/request_1"]]
        or [[curl -X 'POST' -v -s -H 'Content-Type:application/json' --data-binary '{"foo": "bar"}' --cookie 'cookie_key=value' -A 'kulala.nvim/%s' 'http://localhost:3001/request_1']]

      expected = (expected):format(GLOBALS.VERSION):gsub("\n", "")
      result = vim.fn.getreg("+"):gsub("\n", "")
      assert.is.same(expected, result)
    end)

    it("it shows help hint and window", function()
      kulala_config.winbar = false

      kulala.run()
      wait_for_requests(1)

      vim.api.nvim_set_current_buf(ui_buf)

      result = h.get_extmarks(ui_buf, 0, 1, { type = "virt_text" })[1][4].virt_text[1]
      assert.is_same("? - help", result[1])

      h.send_keys("?")
      ui_buf = vim.fn.bufnr("kulala_help")

      result = h.get_buf_lines(ui_buf):to_string()
      assert.has_string(result, "Kulala Help")
    end)

    it("shows winbar", function()
      kulala_config.winbar = true
      kulala_config.default_view = "body"
      kulala_config.default_winbar_panes = { "body", "report", "help" }

      kulala.run()
      wait_for_requests(1)

      result = vim.api.nvim_get_option_value("winbar", { win = vim.fn.bufwinid(ui_buf) })
      expected =
        "%#KulalaTabSel# %1@v:lua.require'kulala.ui.winbar'.select_winbar_tab@Body (B) %*%X %#KulalaTab# %2@v:lua.require'kulala.ui.winbar'.select_winbar_tab@Report (R) %*%X %#KulalaTab# %3@v:lua.require'kulala.ui.winbar'.select_winbar_tab@Help (?) %*%X <- [ ] ->"
      assert.same(expected, result)
    end)
  end)
end)
