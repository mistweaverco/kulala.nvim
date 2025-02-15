local stubs = require("test_helper.stubs")
local ui = require("test_helper.ui")
local asserts = require("test_helper.asserts")

return vim.tbl_extend("error", ui, stubs, asserts)
