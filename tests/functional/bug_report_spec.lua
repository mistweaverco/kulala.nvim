local Config = require("kulala.config")
local bug_report = require("kulala.logger.bug_report")
local h = require("test_helper")

describe("send bug report", function()
  local system, result

  before_each(function()
    Config.setup { default_view = "body", debug = true }
    system = h.System.stub({ "gh" }, {})
  end)

  after_each(function()
    system:reset()
  end)

  it("creates GH issue", function()
    system = h.System.stub({ "gh" }, {
      on_call = function(sys)
        sys.code = 0
        sys.stderr = ""
        sys.stdout = '{"status": "201",   "url": "https://api.github.com/repos/octocat/Hello-World/issues/1347"}'

        result = system.args.cmd
      end,
    })

    bug_report.create_issue("Test issue", "This is a test issue body", { "report", "automated" }, "bug")
    assert.has_strings(result, {
      "gh",
      "api",
      "mistweaverco/kulala.nvim",
      "title=Test issue",
      "body=This is a test issue body",
      "labels[]=report,automated",
      "type=bug",
    })
  end)

  it("generates a bug report", function()
    local _, error = xpcall(vim.fn.NIL, debug.traceback)
    bug_report.generate_bug_report(error)

    result = h.get_buf_lines(vim.fn.bufnr("kulala://bug_report"))
    assert.has_strings(result, {
      "Press `<leader>S` to open a GitHub issue",
      "## Title: [BUG] Vim:E117: Unknown function: NIL",
      "## Description",
      "## Request",
      "## Error ",
      "Vim:E117: Unknown function: NIL",
      "## Health",
      "ℹ {OS}",
      "## User Config",
      "  debug = true,",
    })
  end)
end)
