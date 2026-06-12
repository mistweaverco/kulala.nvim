local data_dir = vim.env.XDG_DATA_HOME .. "/nvim/site"
vim.o.termguicolors = true
vim.opt.swapfile = false
vim.opt.shada = ""
vim.opt.undofile = false

vim.opt.completeopt = { "menu", "menuone", "noselect" }

vim.opt.rtp = {
  vim.env.VIMRUNTIME,
  data_dir,
  vim.fn.getcwd(),
}

_G.TEST = true

local function get_plugins()
  local plugins = {}
  for _, plugin in ipairs(vim.split(vim.env.PLUGINS, " ")) do
    local repo, name = unpack(vim.split(plugin, ";"))
    table.insert(plugins, { repo = repo, name = name })
  end
  return plugins
end

local get_plugin_path = function(plugin)
  return data_dir .. "/pack/plugins/start/" .. plugin.name
end

local function setup_plugin(plugin)
  local package_path = data_dir .. "/pack/plugins/start/" .. plugin.name
  vim.opt.rtp:append(package_path)
  local ok, mod = pcall(require, plugin.name)
  if ok and type(mod.setup) == "function" then mod.setup() end
end

local function ensure_plugins_installed()
  local plugins = get_plugins()
  for _, plugin in ipairs(plugins) do
    local package_path = data_dir .. "/pack/plugins/start/" .. plugin.name
    if vim.fn.isdirectory(package_path) == 0 then
      if vim.startswith(plugin.repo, "file://") then
        local source_path = plugin.repo:sub(8)
        vim.fn.mkdir(package_path, "p")
        vim.fn.system { "cp", "-r", source_path .. "/.", package_path }
        setup_plugin(plugin)
      else
        vim.system({
          "git",
          "clone",
          "--depth",
          "1",
          plugin.repo,
          package_path,
        }, function(obj)
          if obj.code == 0 then vim.schedule(function()
            setup_plugin(plugin)
          end) end
        end)
      end
    else
      setup_plugin(plugin)
    end
  end
end

ensure_plugins_installed()

vim.schedule(function()
  require("kulala.api").on("ready", function()
    local kulala_plugin_path = get_plugin_path { name = "kulala" }
    local tests_dir = kulala_plugin_path .. "/tests"
    package.path = tests_dir .. "/?.lua;" .. tests_dir .. "/?/?.lua;" .. package.path

    local function find_test_files()
      local files = vim.fn.globpath(tests_dir, "**/*_spec.lua", true, true)
      for _, file in ipairs(vim.fn.globpath(tests_dir, "**/test_*.lua", true, true)) do
        if not file:find("/test_helper/") then table.insert(files, file) end
      end
      local filter = vim.env.KULALA_TEST_FILTER
      if filter and filter ~= "" then
        files = vim.tbl_filter(function(f)
          return f:find(filter, 1, true) ~= nil
        end, files)
      end
      return files
    end

    require("kulala.test_helper.globals").install()

    local MiniTest = require("mini.test")
    local reporter = MiniTest.gen_reporter.stdout { progress = "dot" }
    MiniTest.setup {
      collect = { emulate_busted = true },
      execute = { reporter = reporter },
    }
    MiniTest.run {
      collect = { find_files = find_test_files },
      execute = { reporter = reporter },
    }
    vim.wait(600000, function()
      return not MiniTest.is_executing()
    end, 50)

    local n_fail = 0
    for _, case in ipairs(MiniTest.current.all_cases or {}) do
      if case.exec and case.exec.state and case.exec.state:find("Fail") then
        n_fail = n_fail + 1
        for _, msg in ipairs(case.exec.fails or {}) do
          io.write(("[FAIL] %s\n%s\n"):format(table.concat(case.desc or {}, " | "), msg))
        end
      end
    end
    require("kulala.test_helper.globals").uninstall()
    if n_fail > 0 then
      io.write(string.format("\n%d test(s) failed\n", n_fail))
      vim.cmd("cquit 1")
    end
    vim.cmd("qa!")
  end)
end)
