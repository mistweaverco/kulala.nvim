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
