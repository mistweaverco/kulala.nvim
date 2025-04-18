local has_telescope = pcall(require, "telescope")
local has_snacks, snacks_picker = pcall(require, "snacks.picker")
local has_fzf = pcall(require, "fzf-lua")

local DB = require("kulala.db")
local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")

local M = {}

local function get_env()
  local env = DB.find_unique("http_client_env")
  local envs = {}

  for key, _ in pairs(env) do
    if key ~= "$schema" and key ~= "$shared" then table.insert(envs, key) end
  end

  return envs
end

local function get_env_file()
  local file = "http-client.env.json"
  return Fs.find_file_in_parent_dirs(file)
end

local function select_env(env)
  Logger.info("Selected environment: " .. env)
  vim.g.kulala_selected_env = env
end

local open_snacks = function()
  local http_client_env = DB.find_unique("http_client_env")
  if not http_client_env then return Logger.error("No environment found") end

  local items = vim.iter(get_env()):fold({}, function(acc, name)
    local env_data = http_client_env[name] or {}

    table.insert(acc, {
      text = name,
      label = name,
      data = env_data,
      content = vim.inspect(env_data),
      file = get_env_file() or "",
    })
    return acc
  end)

  snacks_picker({
    title = "Select Environment",
    items = items,
    layout = vim.tbl_deep_extend("force", snacks_picker.config.layout("telescope"), {
      reverse = true,
      layout = {
        box = "horizontal",
        width = 0.8,
        height = 0.9,
        { box = "vertical" },
        { win = "preview", width = 0.6 },
      },
    }),

    preview = function(ctx)
      local bufnr = ctx.picker.layout.wins.preview.buf

      vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
      vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(ctx.item.content, "\n"))

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
  })
end

local open_telescope = function()
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local previewers = require("telescope.previewers")
  local config = require("telescope.config").values

  local http_client_env = DB.find_unique("http_client_env")
  if not http_client_env then return Logger.error("No environment found") end

  local envs = get_env()

  pickers
    .new({}, {
      prompt_title = "Select Environment",

      finder = finders.new_table({
        results = envs,
      }),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          _ = selection and select_env(selection.value)
        end)

        return true
      end,

      previewer = previewers.new_buffer_previewer({
        title = "Environment",
        define_preview = function(self, entry)
          local env = http_client_env[entry.value]
          if not env then return end

          local lines = vim.split(vim.inspect(env), "\n")

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.api.nvim_set_option_value("filetype", "lua", { buf = self.state.bufnr })
        end,
      }),

      sorter = config.generic_sorter({}),
    })
    :find()
end

local open_fzf = function()
  local http_client_env = DB.find_unique("http_client_env")
  if not http_client_env then return Logger.error("No environment found") end

  local fzf = require("fzf-lua")
  local builtin_previewer = require("fzf-lua.previewer.builtin")
  local env_previewer = builtin_previewer.base:extend()

  function env_previewer:new(o, opts, fzf_win)
    env_previewer.super.new(self, o, opts, fzf_win)
    setmetatable(self, env_previewer)
    return self
  end

  function env_previewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()

    local env = http_client_env[entry_str]
    if not env then return end

    local lines = vim.split(vim.inspect(env), "\n")

    vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("filetype", "lua", { buf = tmpbuf })
    self:set_preview_buf(tmpbuf)
  end

  -- Disable line numbering and word wrap
  function env_previewer:gen_winopts()
    local new_winopts = {
      wrap = false,
      number = false,
    }
    return vim.tbl_extend("force", self.winopts, new_winopts)
  end
  local envs = get_env()

  local opts = {
    prompt = "Select env",
    previewer = env_previewer,
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then select_env(selected[1]) end
      end,
    },
  }

  fzf.fzf_exec(envs, opts)
end

local function open_selector()
  local envs = get_env()
  local opts = { prompt = "Select env" }

  vim.ui.select(envs, opts, function(result)
    if result then return select_env(result) end
  end)
end

M.open = function()
  if has_snacks then
    open_snacks()
  elseif has_fzf then
    open_fzf()
  elseif has_telescope then
    open_telescope()
  else
    open_selector()
  end
end

return M
