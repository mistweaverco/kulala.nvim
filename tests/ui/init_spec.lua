local GLOBALS = require("kulala.globals")
local UI = require("kulala.ui")
local ui_helper = require("test_helper.ui")

local assert = require("luassert")

describe("kulala.ui", function()
  -- restore all changed done by luassert before each test run
  local snapshot

  before_each(function()
    snapshot = assert:snapshot()
  end)

  after_each(function()
    snapshot:revert()
    ui_helper.delete_all_bufs()
  end)

  describe("from_curl()", function()
    it("pastes simple curl", function()
      local bufnr = ui_helper.create_buf()
      vim.fn.setreg("+", "curl http://example.com")

      UI.from_curl()

      local expected = {
        [[# curl http://example.com]],
        [[GET http://example.com]],
        [[]],
        [[]],
      }
      assert.are.same(expected, ui_helper.get_buf_lines(bufnr))
    end)
  end)

  describe("close()", function()
    local extensions = { "http", "rest" }
    for _, ext in ipairs(extensions) do
      it(("closes ui and %s file"):format(ext), function()
        ui_helper.create_buf({ "" }, "kulala://ui")
        ui_helper.create_buf({ "" }, "file_for_requests." .. ext)

        UI.close()

        local loaded_bufs = ui_helper.list_loaded_bufs()
        for _, bufnr in ipairs(loaded_bufs) do
          local bufname = vim.api.nvim_buf_get_name(bufnr)

          assert.is.True(bufname:find("kulala://ui") == nil, "should have closed the ui")
          assert.is.True(
            bufname:find("file_for_requests." .. ext) == nil,
            "should have closed the file with extension: " .. ext
          )
        end
      end)
    end
  end)
end)
