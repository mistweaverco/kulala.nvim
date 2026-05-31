local kulala = require("kulala")
local kulala_api = require("kulala.api")

kulala.setup()

local contents = [[
POST https://echo.getkulala.net/post HTTP/1.1
Content-Type: application/json

{
  "name": "kulala",
  "age": 1,
  "hobby": ["coding", "eating", "sleeping"]
}
]]

vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(contents, "\n"))

kulala_api.on("ready", function()
  kulala.run()
end)
