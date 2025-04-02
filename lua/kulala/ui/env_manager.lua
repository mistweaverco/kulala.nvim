local has_telescope = pcall(require, "telescope")
local has_snacks, snacks_picker = pcall(require, "snacks.picker")

local DB = require("kulala.db")
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
  elseif has_telescope then
    open_telescope()
  else
    open_selector()
  end
end

return M
