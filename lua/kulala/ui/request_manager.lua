local has_telescope = pcall(require, "telescope")
local has_snacks, snacks_picker = pcall(require, "snacks.picker")

local DB = require("kulala.db")
local Logger = require("kulala.logger")
local Parser = require("kulala.parser.document")
local ParserUtils = require("kulala.parser.utils")

local M = {}

local function get_requests()
  local _, _requests = Parser.get_document()
  if not _requests then return Logger.watn("No requests found in the document") end

  local requests, names = {}, {}

  table.sort(_requests, function(a, b)
    return a.start_line < b.start_line
  end)

  for _, request in ipairs(_requests) do
    local request_name = ParserUtils.get_meta_tag(request, "name") or request.name
    if request_name then
      table.insert(names, request_name)
      requests[request_name] = request
    end
  end

  return requests, names
end

local goto_request = function(request)
  if not request then return end
  local start_line = request.start_line

  vim.cmd("normal! " .. start_line - 1 .. "Gzz")
end

local set_request = function(bufnr, requests, name)
  local request = requests[name]
  if not request then return end

  local lines = vim.api.nvim_buf_get_lines(DB.get_current_buffer(), request.start_line - 1, request.end_line - 1, false)

  vim.api.nvim_set_option_value("filetype", "http", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

local open_snacks = function()
  local requests, names = get_requests()

  local items = vim.iter(names):fold({}, function(acc, name)
    table.insert(acc, { text = name, label = name })
    return acc
  end)

  snacks_picker({
    title = "Document Requests",
    items = items,
    matcher = { sort_empty = false },
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
      set_request(bufnr, requests, ctx.item.label)
      return true
    end,

    win = {
      preview = {
        title = "Reqeuest Preview",
        wo = {
          number = false,
          relativenumber = false,
          signcolumn = "no",
          sidescrolloff = 1,
        },
      },
      list = { title = "Requests" },
    },

    confirm = function(ctx, item)
      ctx:close()
      goto_request(requests[item.label])
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

  local requests, names = get_requests()

  pickers
    .new({}, {
      prompt_title = "Search document requests",
      results_title = "Requests",
      finder = finders.new_table({
        results = names,
      }),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          goto_request(requests[selection.value])
        end)

        return true
      end,

      previewer = previewers.new_buffer_previewer({
        title = "Request Preview",
        define_preview = function(self, entry)
          set_request(self.state.bufnr, requests, entry.value)
        end,
      }),

      sorter = config.generic_sorter({}),
    })
    :find()
end

local function open_selector()
  local requests, names = get_requests()
  local opts = { prompt = "Search requests" }

  vim.ui.select(names, opts, function(result)
    if result then goto_request(requests[result]) end
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
