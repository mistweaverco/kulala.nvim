local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local kulala = require("kulala")

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")

describe("kulala.ui", function()
  describe("show output of requests", function()
    local curl, jobstart, system, fs
    local result, expected, ui_buf

    before_each(function()
      curl = s.Curl:stub({
        ["*"] = {
          headers = h.load_fixture("request_1_headers.txt"),
          stats = h.load_fixture("request_1_stats.txt"),
        },
        ["http://localhost:3001/greeting"] = {
          body = h.load_fixture("request_1_body.txt"),
          errors = h.load_fixture("request_1_errors.txt"),
        },
        ["http://localhost:3001/echo"] = {
          body = h.load_fixture("request_2_body.txt"),
          errors = h.load_fixture("request_2_errors.txt"),
        },
      })

      jobstart = s.Jobstart:stub({ "curl" }, {
        on_call = function(self)
          curl:request(self)
        end,
        on_exit = 0,
      })

      system = s.System:stub({ "curl" }, {
        on_call = function(self)
          curl:request(self)
        end,
      })
    end)

    after_each(function()
      h.delete_all_bufs()
      curl:reset()
      jobstart:reset()
      system:reset()
    end)

    it("shows request output in verbose mode for run_one", function()
      local lines = h.to_table(
        [[
        GET http://localhost:3001/greeting
      ]],
        true
      )

      h.create_buf(lines, "test.http")
      CONFIG.options.default_view = "verbose"

      kulala.run()
      jobstart:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return ui_buf > 0
      end)

      result = h.get_buf_lines(ui_buf):to_string()
      expected = h.load_fixture("request_1_verbose.txt")

      assert.is_same(expected, result)
    end)

    it("shows last request output in verbose mode for run_all", function()
      local lines = h.to_table(
        [[
        GET http://localhost:3001/greeting

        ###

        GET http://localhost:3001/echo
      ]],
        true
      )

      h.create_buf(lines, "test.http")
      CONFIG.options.default_view = "verbose"

      kulala.run_all()

      system:wait(3000, function()
        ui_buf = vim.fn.bufnr(GLOBALS.UI_ID)
        return curl.requests_no == 2 and ui_buf ~= -1
      end)

      expected = h.load_fixture("request_2_verbose.txt")
      result = h.get_buf_lines(ui_buf):to_string()

      assert.is_same(2, curl.requests_no)
      assert.is_same(expected, result)
    end)
  end)
end)
