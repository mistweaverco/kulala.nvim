local has_telescope = pcall(require, "telescope")
local has_snacks, snacks_picker = pcall(require, "snacks.picker")
local has_fzf = pcall(require, "fzf-lua")

local Config = require("kulala.config")
local DB = require("kulala.db")
local Env = require("kulala.parser.env")
local Fs = require("kulala.utils.fs")
local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")
local Logger = require("kulala.logger")

local M = {}

local template = {
  ["$schema"] = "https://raw.githubusercontent.com/mistweaverco/kulala.nvim/main/schemas/http-client.env.schema.json",
  ["$kulalaShared"] = {
    ["$kulalaDefaultHeaders"] = {},
  },
  dev = {
    Security = { Auth = {} },
  },
  prod = {},
}

---@class kulala.env_catalog_cache
---@field key string|nil
---@field http_client_env table|nil
---@field http_client_env_shared table|nil
---@field loading boolean
---@field loading_key string|nil
---@field waiters fun(http_client_env: table|nil, err: string|nil)[]

local catalog_cache = {
  key = nil,
  http_client_env = nil,
  http_client_env_shared = nil,
  loading = false,
  loading_key = nil,
  waiters = {},
}

local ENV_FILE_NAMES = {
  "http-client.env.json",
  "http-client.private.env.json",
  "kuba.yaml",
}

local function find_env_files_upward(filename, start_dir)
  start_dir = start_dir or Fs.get_current_buffer_dir()
  local root = vim.fs.root(start_dir, { ".git", ".gitignore" })
  root = root and (root .. "/..") or "/"
  return vim.fs.find(filename, {
    path = start_dir,
    upward = true,
    type = "file",
    limit = math.huge,
    stop = root,
  })
end

---@param cwd string
---@return string
local function env_catalog_cache_key(cwd)
  local parts = { cwd }
  for _, name in ipairs(ENV_FILE_NAMES) do
    for _, path in ipairs(find_env_files_upward(name, cwd)) do
      local mtime = vim.fn.getftime(path)
      if mtime >= 0 then table.insert(parts, path .. ":" .. tostring(mtime)) end
    end
  end
  table.sort(parts)
  return table.concat(parts, "\n")
end

function M.invalidate_cache()
  catalog_cache.key = nil
  catalog_cache.http_client_env = nil
  catalog_cache.http_client_env_shared = nil
end

local function create_env_file()
  local name = "http-client.env.json"

  local path = Fs.find_file_in_parent_dirs(name)
  if path or vim.fn.confirm("Create " .. name .. "?", "&Yes\n&No") == 2 then return path end

  path = Fs.get_current_buffer_dir() .. "/" .. name
  Fs.write_json(path, template)
  Logger.info("Created env file: " .. path)

  return path
end

---@return table http_client_env
---@return table http_client_env_shared
local function read_http_client_env_from_disk()
  local http_client_env = {}
  local http_client_env_shared = {}

  local function merge_kulala_shared(dst, kulala_shared)
    if type(kulala_shared) ~= "table" then return end
    kulala_shared = vim.deepcopy(kulala_shared)
    kulala_shared["$kulalaDefaultHeaders"] = nil
    vim.tbl_deep_extend("force", dst, kulala_shared)
  end

  vim.iter(Fs.find_files_in_parent_dirs("http-client.env.json") or {}):rev():each(function(file)
    local f = Fs.read_json(file) or {}
    merge_kulala_shared(http_client_env_shared, f["$kulalaShared"])
    f["$kulalaShared"], f["$schema"] = nil, nil
    http_client_env = vim.tbl_deep_extend("force", http_client_env, f)
  end)

  vim.iter(Fs.find_files_in_parent_dirs("http-client.private.env.json") or {}):rev():each(function(file)
    local f = Fs.read_json(file) or {}
    merge_kulala_shared(http_client_env_shared, f["$kulalaShared"])
    f["$kulalaShared"], f["$schema"] = nil, nil
    http_client_env = vim.tbl_deep_extend("force", http_client_env, f)
  end)

  return http_client_env, http_client_env_shared
end

---@param core_catalog table|nil
---@param disk_env table
---@param disk_shared table
---@return table|nil http_client_env
---@return table http_client_env_shared
local function merge_catalogs(core_catalog, disk_env, disk_shared)
  local http_client_env = (core_catalog and core_catalog.environments) or {}
  local http_client_env_shared = {}
  if core_catalog and type(core_catalog["$kulalaShared"]) == "table" then
    http_client_env_shared = vim.deepcopy(core_catalog["$kulalaShared"])
    http_client_env_shared["$kulalaDefaultHeaders"] = nil
  end

  http_client_env = vim.tbl_deep_extend("force", vim.deepcopy(http_client_env), disk_env)
  http_client_env_shared = vim.tbl_deep_extend("force", vim.deepcopy(http_client_env_shared), disk_shared)

  if next(http_client_env) == nil then return nil, http_client_env_shared end
  return http_client_env, http_client_env_shared
end

---@param http_client_env table
---@param http_client_env_shared table
local function store_catalog_in_db(http_client_env, http_client_env_shared)
  DB.update().http_client_env = http_client_env
  DB.update().http_client_env_shared = http_client_env_shared
end

---@param cache_key string
---@param http_client_env table|nil
---@param http_client_env_shared table|nil
local function finish_catalog_load(cache_key, http_client_env, http_client_env_shared)
  if http_client_env then
    catalog_cache.key = cache_key
    catalog_cache.http_client_env = http_client_env
    catalog_cache.http_client_env_shared = http_client_env_shared or {}
    store_catalog_in_db(http_client_env, catalog_cache.http_client_env_shared)
  end

  catalog_cache.loading = false
  catalog_cache.loading_key = nil

  local waiters = catalog_cache.waiters
  catalog_cache.waiters = {}
  for _, cb in ipairs(waiters) do
    cb(http_client_env, http_client_env and nil or "No environment found")
  end
end

---@param force? boolean
---@param on_done fun(http_client_env: table|nil, err: string|nil)
local function refresh_environment_catalog_async(force, on_done)
  local _, cwd = KULALA_CORE.resolve_document_paths(0, nil)
  cwd = cwd or vim.loop.cwd()
  local cache_key = env_catalog_cache_key(cwd)

  if not force and catalog_cache.key == cache_key and catalog_cache.http_client_env then
    vim.schedule(function()
      store_catalog_in_db(catalog_cache.http_client_env, catalog_cache.http_client_env_shared or {})
      on_done(catalog_cache.http_client_env, nil)
    end)
    return
  end

  if catalog_cache.loading and catalog_cache.loading_key == cache_key then
    table.insert(catalog_cache.waiters, on_done)
    return
  end

  catalog_cache.loading = true
  catalog_cache.loading_key = cache_key
  catalog_cache.waiters = { on_done }

  Logger.info("Loading environments…")

  local disk_env, disk_shared = read_http_client_env_from_disk()

  local function finish(core_catalog)
    local http_client_env, http_client_env_shared = merge_catalogs(core_catalog, disk_env, disk_shared)
    finish_catalog_load(cache_key, http_client_env, http_client_env_shared)
  end

  if KULALA_CORE.enabled() then
    KULALA_CORE.list_environments_async(cwd, function(catalog, err)
      if err and not catalog then
        -- Fall back to disk-only when core fails
        local http_client_env, http_client_env_shared = merge_catalogs(nil, disk_env, disk_shared)
        if http_client_env then
          finish_catalog_load(cache_key, http_client_env, http_client_env_shared)
        else
          finish_catalog_load(cache_key, nil, nil)
          Logger.warn(err)
        end
        return
      end
      finish(catalog)
    end)
  else
    vim.schedule(function()
      finish(nil)
    end)
  end
end

---@param force? boolean
---@param on_done fun(http_client_env: table|nil, err: string|nil)
function M.refresh_async(force, on_done)
  refresh_environment_catalog_async(force, on_done)
end

local function get_env_names(http_client_env)
  local envs = {}
  for key, _ in pairs(http_client_env or {}) do
    if key ~= "$kulalaShared" then table.insert(envs, key) end
  end
  table.sort(envs)
  return envs
end

local function get_env_file()
  return Fs.find_file_in_parent_dirs("http-client.env.json")
end

local function select_env(env)
  Logger.info("Selected environment: " .. env)
  vim.g.kulala_selected_env = env
  DB.update().selected_env = env
end

local function set_buffer(buf, content)
  if not content then return end
  content = vim.split(vim.inspect(content), "\n")

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "lua", { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
end

local function open_snacks(http_client_env)
  local items = vim.iter(get_env_names(http_client_env)):fold({}, function(acc, name)
    local env_data = http_client_env[name] or {}

    table.insert(acc, {
      text = name,
      label = name,
      data = env_data,
      content = env_data,
      file = get_env_file() or "",
    })
    return acc
  end)

  snacks_picker {
    title = "Select Environment",
    items = items,
    layout = Config.options.ui.pickers.snacks.layout,

    preview = function(ctx)
      set_buffer(ctx.picker.layout.wins.preview.buf, ctx.item.content)
      return true
    end,

    win = {
      preview = {
        title = "Environment Variables",
        wo = {
          number = false,
          relativenumber = false,
          signcolumn = "no",
          sidescrolloff = 1,
        },
      },
      list = { title = "Environments" },
    },

    confirm = function(ctx, item)
      select_env(item.label)
      ctx:close()
    end,
  }

  return true
end

local function open_telescope(http_client_env)
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local previewers = require("telescope.previewers")
  local config = require("telescope.config").values

  local envs = get_env_names(http_client_env)

  pickers
    .new({}, {
      prompt_title = "Select Environment",

      finder = finders.new_table {
        results = envs,
      },

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then select_env(selection.value) end
        end)

        return true
      end,

      previewer = previewers.new_buffer_previewer {
        title = "Environment",
        define_preview = function(self, entry)
          set_buffer(self.state.bufnr, http_client_env[entry.value])
        end,
      },

      sorter = config.generic_sorter {},
    })
    :find()
end

local function open_fzf(http_client_env)
  local fzf = require("fzf-lua")
  local builtin_previewer = require("fzf-lua.previewer.builtin")
  local env_previewer = builtin_previewer.base:extend()

  function env_previewer:new(o, opts, fzf_win)
    env_previewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, env_previewer)
    return self
  end

  function env_previewer:populate_preview_buf(entry_str)
    local buf = self:get_tmp_buffer()
    set_buffer(buf, http_client_env[entry_str])
    self:set_preview_buf(buf)
  end

  function env_previewer:gen_winopts()
    return vim.tbl_extend("force", self.winopts, { wrap = false, number = false })
  end

  local envs = get_env_names(http_client_env)

  fzf.fzf_exec(envs, {
    prompt = "Select env ",
    previewer = env_previewer,
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then select_env(selected[1]) end
      end,
    },
  })
end

local function open_selector(http_client_env)
  local envs = get_env_names(http_client_env)
  vim.ui.select(envs, { prompt = "Select env" }, function(result)
    if result then select_env(result) end
  end)
end

local function open_picker(http_client_env)
  if has_snacks then
    if snacks_picker.config.get().ui_select then
      open_snacks(http_client_env)
    else
      open_selector(http_client_env)
    end
  elseif has_fzf then
    open_fzf(http_client_env)
  elseif has_telescope then
    open_telescope(http_client_env)
  else
    open_selector(http_client_env)
  end
end

---@param opts? { force?: boolean }
local env_cache_augroup = vim.api.nvim_create_augroup("kulala_env_catalog_cache", { clear = true })
vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  group = env_cache_augroup,
  callback = function(ev)
    local name = vim.fn.fnamemodify(ev.match, ":t")
    if vim.tbl_contains(ENV_FILE_NAMES, name) then M.invalidate_cache() end
  end,
})

---@param opts? { force?: boolean }
M.open = function(opts)
  opts = opts or {}
  refresh_environment_catalog_async(opts.force, function(http_client_env, err)
    if not http_client_env then
      if err and err ~= "No environment found" then Logger.error(err, 1) end
      create_env_file()
      Env.get_env()
      http_client_env = DB.find_unique("http_client_env")
      if not http_client_env then return Logger.error("No environment found") end
    end
    open_picker(http_client_env)
  end)
end

return M
