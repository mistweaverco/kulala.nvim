local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local kulala = require("kulala")

local h = require("test_helper.ui")
local s = require("test_helper.stubs")

local assert = require("luassert")

describe("kulala.ui", function()
  describe("show output of requests", function()
    local jobstart, fs
    local result, expected

    before_each(function()
      jobstart = s.Jobstart:stub("test_cmd", {
        on_stdout = {},
        on_stderr = { "Test stderr" },
        on_exit = 0,
      })

      fs = s.Fs:stub_read_file {
        [GLOBALS.HEADERS_FILE] = h.to_string[[
          HTTP/1.1 200 OK
          Date: Sun, 26 Jan 2025 00:14:41 GMT
          Transfer-Encoding: chunked
          Server: Jetty(9.4.36.v20210114)
        ]],
        [GLOBALS.BODY_FILE] = "Hello, World!",
        [GLOBALS.ERRORS_FILE] = h.load_fixture("request_1_errors.txt")
      }
    end)

    after_each(function()
      jobstart:reset()
      fs:read_file_reset()
    end)

    it("shows output in verbose mode", function()
      local lines = h.to_table[[
        GET http://localhost:3001/echo

        ###

        GET http://localhost:3001/greeting
      ]]

      h.create_buf(lines, vim.uv.cwd() .. "test.http")
      CONFIG.options.default_view = "verbose"

      kulala.run()
      jobstart:wait(1000)

      result = h.to_string(h.get_buf_lines(vim.fn.bufnr("kulala://ui")), false)
      expected = h.load_fixture("request_1_verbose.txt")

      assert.is_same(expected, result)
    end)
  end)
end)
