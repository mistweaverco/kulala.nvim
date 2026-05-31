---Project test entry for mini.test (`MiniTest.run()` / `luafile scripts/minitest.lua`).
require("kulala.test_helper.globals").install()

local tests_dir = vim.fn.getcwd() .. "/tests"

local function find_test_files()
  local files = vim.fn.globpath(tests_dir, "**/*_spec.lua", true, true)
  for _, file in ipairs(vim.fn.globpath(tests_dir, "**/test_*.lua", true, true)) do
    if not file:find("/test_helper/") then table.insert(files, file) end
  end
  return files
end

require("mini.test").run {
  collect = {
    emulate_busted = true,
    find_files = find_test_files,
  },
}

require("kulala.test_helper.globals").uninstall()
