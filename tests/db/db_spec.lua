local DB = require("kulala.db")

describe("db scoped", function()
  it("should not leak into other buffers", function()
    vim.cmd("new")
    local buf1 = vim.api.nvim_get_current_buf()

    DB.current_buffer = buf1
    DB.update().key1 = "value1"
    assert.are.equal("value1", DB.find_unique("key1"))

    vim.cmd("new")
    local buf2 = vim.api.nvim_get_current_buf()

    DB.current_buffer = buf2
    DB.update().key2 = "value2"
    assert.is_nil(DB.find_unique("key1"))
    assert.are.equal("value2", DB.find_unique("key2"))

    vim.api.nvim_set_current_buf(buf1)
    DB.current_buffer = buf1
    assert.are.equal("value1", DB.find_unique("key1"))
    assert.is_nil(DB.find_unique("key2"))

    vim.api.nvim_set_current_buf(buf2)
    DB.current_buffer = buf2
    assert.is_nil(DB.find_unique("key1"))
    assert.are.equal("value2", DB.find_unique("key2"))
  end)
end)
