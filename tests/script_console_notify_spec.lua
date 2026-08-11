local CONFIG = require("kulala.config")
local NOTIFY = require("kulala.script_console_notify")

describe("script_console_notify", function()
  local original_notify
  local calls

  before_each(function()
    original_notify = vim.notify
    calls = {}
    vim.notify = function(message, level, opts)
      table.insert(calls, { message = message, level = level, opts = opts })
    end
    local base = require("kulala.test_helper.kulala_core").config()
    CONFIG.setup(vim.tbl_extend("force", base, {
      script_console_notify = {
        notify = function(message, level, opts)
          vim.notify(message, level, opts)
        end,
      },
    }))
  end)

  after_each(function()
    vim.notify = original_notify
  end)

  it("forwards console and client.log lines to vim.notify by default", function()
    NOTIFY.emit {
      { level = "log", message = "hello from client.log" },
      { level = "info", message = "info line" },
      { level = "warn", message = "warn line" },
      { level = "error", message = "error line" },
      { level = "debug", message = "debug line" },
    }

    assert.are.equal(5, #calls)
    assert.are.equal("hello from client.log", calls[1].message)
    assert.are.equal(vim.log.levels.INFO, calls[1].level)
    assert.are.equal("kulala", calls[1].opts.title)
    assert.are.equal(vim.log.levels.WARN, calls[3].level)
    assert.are.equal(vim.log.levels.ERROR, calls[4].level)
    assert.are.equal(vim.log.levels.DEBUG, calls[5].level)
  end)

  it("does not notify test or assert structured lines", function()
    NOTIFY.emit {
      { level = "log", message = "plain", kind = "log" },
      { level = "log", message = "passed test", kind = "test", status = "pass" },
      { level = "error", message = "failed assert", kind = "assert", status = "fail" },
    }

    assert.are.equal(1, #calls)
    assert.are.equal("plain", calls[1].message)
  end)

  it("can be disabled via config", function()
    CONFIG.setup { script_console_notify = false }
    NOTIFY.emit { { level = "log", message = "silent" } }
    assert.are.equal(0, #calls)
  end)

  it("supports a custom notify handler", function()
    local custom_calls = {}
    CONFIG.setup {
      script_console_notify = {
        notify = function(message, level, opts, entry)
          table.insert(custom_calls, { message = message, level = level, entry = entry })
        end,
      },
    }
    NOTIFY.emit { { level = "error", message = "custom" } }
    assert.are.equal(0, #calls)
    assert.are.equal(1, #custom_calls)
    assert.are.equal("custom", custom_calls[1].message)
    assert.are.equal(vim.log.levels.ERROR, custom_calls[1].level)
  end)
end)
