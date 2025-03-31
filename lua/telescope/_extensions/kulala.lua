local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then return nil end

local Parser = require("kulala.parser.document")
local ParserUtils = require("kulala.parser.utils")

local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local config = require("telescope.config").values

local function kulala_search(_)
  local _, requests = Parser.get_document()

  if requests == nil then return end

  local data = {}
  local names = {}

  for _, request in ipairs(requests) do
    local request_name = ParserUtils.get_meta_tag(request, "name")
    if request_name ~= nil then
      table.insert(names, request_name)
      data[request_name] = request
    end
  end

  pickers
    .new({}, {
      prompt_title = "Search",
      finder = finders.new_table({
        results = names,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection == nil then return end
          local request = data[selection.value]
          vim.cmd("normal! " .. request.start_line + 1 .. "G")
        end)
        return true
      end,
      previewer = previewers.new_buffer_previewer({
        title = "Preview",
        define_preview = function(self, entry)
          local request = data[entry.value]
          if request == nil then return end
          local lines = {}
          local http_version = request.http_version and "HTTP/" .. request.http_version or "HTTP/1.1"
          table.insert(lines, request.method .. " " .. request.url .. " " .. http_version)
          for key, value in pairs(request.headers) do
            table.insert(lines, key .. ": " .. value)
          end
          if request.body_display ~= nil then
            table.insert(lines, "")
            local body_as_table = vim.split(request.body_display, "\r?\n")
            for _, line in ipairs(body_as_table) do
              table.insert(lines, line)
            end
          end
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.bo[self.state.bufnr].filetype = "http"
        end,
      }),
      sorter = config.generic_sorter({}),
    })
    :find()
end

return telescope.register_extension({
  exports = {
    search = kulala_search,
  },
})
