local GLOBALS = require("kulala.globals")
local UI = require("kulala.ui")

local assert = require("luassert")

describe("kulala.ui", function()
  -- restore all changed done by luassert before each test run
  local snapshot

  before_each(function()
    snapshot = assert:snapshot()
  end)

  after_each(function()
    snapshot:revert()
  end)

  it("_buffer_exists", function()
    local nvim_list_bufs = stub(vim.api, "nvim_list_bufs", function()
      return { 1, 2 }
    end)
    local nvim_buf_get_name = stub(vim.api, "nvim_buf_get_name", function(bufnr)
      if bufnr == 2 then
        return GLOBALS.UI_ID
      end
    end)

    local exist = UI._buffer_exists()
    assert.is_true(exist)
    assert.stub(nvim_list_bufs).was.called(1)
    assert.stub(nvim_buf_get_name).was.called_with(1)
    assert.stub(nvim_buf_get_name).was.called_with(2)
  end)

  it("_buffer_not_exists", function()
    local nvim_list_bufs = stub(vim.api, "nvim_list_bufs", function()
      return { 1, 2 }
    end)
    local nvim_buf_get_name = stub(vim.api, "nvim_buf_get_name", function()
      return nil
    end)

    local exist = UI._buffer_exists()
    assert.is_false(exist)
    assert.stub(nvim_list_bufs).was.called(1)
    assert.stub(nvim_buf_get_name).was.called_with(1)
    assert.stub(nvim_buf_get_name).was.called_with(2)
  end)

  it("from_curl", function()
    local getreg = stub(vim.fn, "getreg", function()
      return "curl http://example.com"
    end)
    local nvim_put = stub(vim.api, "nvim_put")

    UI.from_curl()

    assert.stub(getreg).was.called_with("+")
    local expected = {
      [[# curl http://example.com]],
      [[GET http://example.com]],
      "",
    }
    assert.stub(nvim_put).was.called_with(expected, "l", false, false)
  end)

  it("close", function()
    local buffer_exists = stub(UI, "_buffer_exists", function()
      return true
    end)
    local close_buffer = stub(UI, "_close_buffer")
    local expand = stub(vim.fn, "expand", function()
      return "http"
    end)
    local cmd = stub(vim, "cmd")

    UI.close()

    assert.stub(buffer_exists).was.called(1)
    assert.stub(close_buffer).was.called(1)
    assert.stub(expand).was.called(1)
    assert.stub(expand).was.called_with("%:e")
    assert.stub(cmd).was.called_with("bdelete")
  end)
end)
