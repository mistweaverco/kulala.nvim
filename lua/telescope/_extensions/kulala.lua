local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  return nil
end

local DB = require("kulala.db")
local FS = require("kulala.utils.fs")

local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local config = require("telescope.config").values

local function kulala_search(_)
  -- a list of all the .http/.rest files in the current directory
  -- and its subdirectories
  local files = FS.find_all_http_files()

  pickers
    .new({}, {
      prompt_title = "Search",
      finder = finders.new_table({
        results = files,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection == nil then
            return
          end
          vim.cmd("e " .. selection.value)
        end)
        return true
      end,
      previewer = previewers.vim_buffer_cat.new({
        title = "Preview",
      }),
      sorter = config.generic_sorter({}),
    })
    :find()
end

local function kulala_env_select(_)
  if not DB.get().data.http_client_env then
    return
  end

  local envs = {}
  for key, _ in pairs(DB.get().data.http_client_env) do
    table.insert(envs, key)
  end

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
          if selection == nil then
            return
          end
          vim.g.kulala_selected_env = selection.value
        end)
        return true
      end,
      previewer = previewers.new_buffer_previewer({
        title = "Environment",
        define_preview = function(self, entry)
          local env = DB.get().data.http_client_env[entry.value]
          if env == nil then
            return
          end
          local lines = {}
          for key, value in pairs(env) do
            table.insert(lines, string.format("%s: %s", key, value))
          end
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        end,
      }),
      sorter = config.generic_sorter({}),
    })
    :find()
end

return telescope.register_extension({
  exports = {
    search = kulala_search,
    select_env = kulala_env_select,
  },
})
