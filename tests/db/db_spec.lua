local DB = require("kulala.db")

describe("db scoped", function()
  it("should not leak into other buffers", function()
    vim.cmd("new")
    local buf1 = vim.api.nvim_get_current_buf()

    DB.current_buffer = buf1
    DB.update().key1 = "value1"
    assert.equal(DB.find_unique("key1"), "value1")

    vim.cmd("new")
    local buf2 = vim.api.nvim_get_current_buf()

    DB.current_buffer = buf2
    DB.update().key2 = "value2"
    assert.equal(DB.find_unique("key1"), nil)
    assert.equal(DB.find_unique("key2"), "value2")

    vim.api.nvim_set_current_buf(buf1)
    DB.current_buffer = buf1
    assert.equal(DB.find_unique("key1"), "value1")
    assert.equal(DB.find_unique("key2"), nil)

    vim.api.nvim_set_current_buf(buf2)
    DB.current_buffer = buf2
    assert.equal(DB.find_unique("key1"), nil)
    assert.equal(DB.find_unique("key2"), "value2")
  end)
end)
