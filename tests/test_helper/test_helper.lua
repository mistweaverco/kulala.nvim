local asserts = require("test_helper.asserts")
local stubs = require("test_helper.stubs")
local ui = require("test_helper.ui")

return vim.tbl_extend("error", ui, stubs, asserts)
