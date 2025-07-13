---@diagnostic disable: undefined-field, redefined-local
local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local kulala = require("kulala")

local h = require("test_helper")

describe("requests report", function()
  local kulala_config, report_config
  local curl, system, wait_for_requests
  local result, db, ui_buf

  before_each(function()
    db = DB.global_update()

    db.responses = {}
    h.delete_all_bufs()

    curl = h.Curl.stub {
      ["*"] = {
        headers = h.load_fixture("fixtures/advanced_E_headers.txt"),
        stats = h.load_fixture("fixtures/stats.json"),
      },
      ["https://httpbin.org/post"] = {
        body = h.load_fixture("fixtures/report.txt"),
      },
      ["https://httpbin.org/html"] = {
        body = h.load_fixture("fixtures/request_2_body.txt"),
      },
    }

    system = h.System.stub({ "curl" }, {
      on_call = function(system)
        curl.request(system)
      end,
    })

    wait_for_requests = function(requests_no)
      system:wait(3000, function()
        ui_buf = h.get_kulala_buf()
        return curl.requests_no == requests_no and ui_buf > 0
      end)
    end
  end)

  after_each(function()
    h.delete_all_bufs()
    curl.reset()
    system.reset()
  end)

  describe("report outtput", function()
    before_each(function()
      kulala_config = CONFIG.setup {
        default_view = "report",
        display_mode = "split",
        halt_on_error = false,

        ui = {
          disable_script_print_output = true,
          report = {
            show_script_output = false,
            show_asserts_output = true,
            show_summary = true,
          },
        },
      }

      report_config = kulala_config.ui.report
      vim.cmd.edit(h.expand_path("requests/report.http"))

      kulala.run_all()
      wait_for_requests(2)
    end)

    after_each(function()
      CONFIG.setup()
    end)

    it("has headers", function()
      result = h.get_buf_lines(ui_buf)[1]
      assert.has_string(result, "Line")
      assert.has_string(result, "URL")
      assert.has_string(result, "Status")
      assert.has_string(result, "Time")
      assert.has_string(result, "Duration")

      assert.is_true(h.has_highlight(ui_buf, 0, report_config.headersHighlight))
    end)

    it("has request summary", function()
      vim.uv.os_setenv("TZ", "UTC")

      db.responses[1].duration = 220223
      db.responses[1].time = 1741034503

      db.responses[2].duration = 333604
      db.responses[2].time = 1741034503

      kulala.open()
      ui_buf = h.get_kulala_buf()

      result = h.get_buf_lines(ui_buf)[3]
      assert.has_string(result, "3")
      assert.has_string(result, "https://httpbin.org/post?key1=value1")
      assert.has_string(result, "200")
      assert.has_string(result, "20:41:43")
      assert.has_string(result, "0.22 ms")

      assert.is_true(h.has_highlight(ui_buf, 2, report_config.errorHighlight))

      result = h.get_buf_lines(ui_buf)[18]
      assert.has_string(result, "41")
      assert.has_string(result, "https://httpbin.org/html")
      assert.has_string(result, "200")
      assert.has_string(result, "20:41:43")
      assert.has_string(result, "0.33 ms")

      assert.is_true(h.has_highlight(ui_buf, 17, report_config.successHighlight))
    end)

    it("correctly executes assertions", function()
      result = h.get_buf_lines(ui_buf):to_string()

      assert.has_string(result, "Test suite name 1:")
      assert.is_true(h.has_highlight(ui_buf, 4, report_config.headersHighlight))

      assert.has_string(result, "Assertion failed")
      assert.is_true(h.has_highlight(ui_buf, 5, report_config.errorHighlight))

      assert.has_string(result, "2: assert")
      assert.is_true(h.has_highlight(ui_buf, 6, report_config.successHighlight))

      assert.has_string(result, 'Assertion failed: expected "3: assert.same", got "Developer"')
      assert.has_string(result, '4: assert.same: expected "Developer", got "Developer"')
      assert.has_string(result, '5: client.assert.true: expected "true", got "false"')
      assert.is_true(h.has_highlight(ui_buf, 9, report_config.errorHighlight))
      assert.has_string(result, '6: client.assert.false: expected "false", got "false"')

      assert.has_string(result, "Test suite name 2:")
      assert.is_true(h.has_highlight(ui_buf, 11, report_config.headersHighlight))

      assert.has_string(result, '7: hasString: expected "Develop", got "Developer"')
      assert.has_string(result, '8: responseHas: expected "200", got "200"')
      assert.has_string(result, '9: headersHas: expected "application/json", got "application/json"')
      assert.has_string(result, '10: jsonHas: expected "Developer", got "Developer"')

      assert.has_string(result, '11: bodyHas: expected "Hello", got "Hello, World!')
      assert.is_true(h.has_highlight(ui_buf, 20, report_config.successHighlight))
    end)

    it("has summary stats", function()
      result = h.get_buf_lines(ui_buf)
      result = h.get_buf_lines(ui_buf)[24]

      assert.has_string(result, "Summary")
      assert.has_string(result, "Total")
      assert.has_string(result, "Successful")
      assert.has_string(result, "Failed")

      assert.is_true(h.has_highlight(ui_buf, 23, report_config.headersHighlight))

      result = h.get_buf_lines(ui_buf)[25]
      assert.has_string(result, "Requests")
      assert.has_string(result, "2")
      assert.has_string(result, "1")
      assert.has_string(result, "1")
      assert.is_true(h.has_highlight(ui_buf, 24, report_config.successHighlight))
      assert.is_true(h.has_highlight(ui_buf, 24, report_config.errorHighlight))

      result = h.get_buf_lines(ui_buf)[26]
      assert.has_string(result, "Asserts")
      assert.has_string(result, "11")
      assert.has_string(result, "8")
      assert.has_string(result, "3")
      assert.is_true(h.has_highlight(ui_buf, 25, report_config.successHighlight))
      assert.is_true(h.has_highlight(ui_buf, 24, report_config.errorHighlight))
    end)

    it("follows report config options - script output", function()
      report_config.show_script_output = true
      kulala.open()
      result = h.get_buf_lines(ui_buf)

      assert.has_string(result, "<-- Post-script:")
      assert.has_string(result, "Test Script Output 1")
      assert.has_string(result, "Test Script Output 2")

      report_config.show_script_output = false
      kulala.open()
      result = h.get_buf_lines(ui_buf)

      assert.is_not.has_string(result, "<-- Post-script:")
      assert.is_not.has_string(result, "Test Script Output 1")
      assert.is_not.has_string(result, "Test Script Output 2")

      report_config.show_script_output = "on_error"
      kulala.open()
      result = h.get_buf_lines(ui_buf)

      assert.has_string(result, "<-- Post-script:")
      assert.has_string(result, "Test Script Output 1")
      assert.is_not.has_string(result, "Test Script Output 2")
    end)

    it("follows report config options - asserts output", function()
      report_config.show_asserts_output = false
      kulala.open()
      result = h.get_buf_lines(ui_buf)

      assert.is_not.has_string(result, "Assertion failed")

      report_config.show_asserts_output = "on_error"
      kulala.open()
      result = h.get_buf_lines(ui_buf)
      assert.has_string(result, "Assertion failed")
      assert.is_not.has_string(result, '11: bodyHas: expected "Hello"')

      report_config.show_asserts_output = "failed_only"
      kulala.open()
      result = h.get_buf_lines(ui_buf)

      assert.has_string(result, "Assertion failed")
      assert.is_not.has_string(result, '7: hasString: expected "Develop", got "Developer"')
    end)

    it("has summary stats", function()
      report_config.show_summary = false
      kulala.open()
      result = h.get_buf_lines(ui_buf)

      assert.is_not.has_string(result, "Summary")
      assert.is_not.has_string(result, "Total")
      assert.is_not.has_string(result, "Successful")
    end)

    it("jumps to request under cursor", function()
      vim.api.nvim_set_current_win(vim.fn.bufwinid(ui_buf))
      h.send_keys("gg2j")

      require("kulala.ui").keymap_enter()

      result = h.get_buf_lines(h.get_kulala_buf())
      assert.has_string(result[1], "Request: 1/2")
    end)
  end)
end)
