local has_telescope = pcall(require, "telescope")
local has_snacks, snacks_picker = pcall(require, "snacks.picker")

local Config = require("kulala.config")
local DB = require("kulala.db")
local Logger = require("kulala.logger")
local Parser = require("kulala.parser.document")
local Ui = require("kulala.ui")

local M = {}

local requests, names = {}, {}

local function get_requests()
  DB.set_current_buffer()

  local _requests = Parser.get_document()
  if not _requests then return Logger.watn("No requests found in the document") end

  requests, names = {}, {}

  table.sort(_requests, function(a, b)
    return a.start_line < b.start_line
  end)

  for _, request in ipairs(_requests) do
    table.insert(names, request.name)
    requests[request.name] = request
  end

  return requests, names
end

local goto_request = function(request)
  if not request then return end
  local start_line = request.start_line

  vim.cmd("normal! " .. start_line .. "Gzz")
end

local set_request = function(bufnr, requests, name)
  local request = requests[name]
  if not request then return end

  local lines = vim.api.nvim_buf_get_lines(DB.get_current_buffer(), request.start_line - 1, request.end_line - 1, false)

  vim.api.nvim_set_option_value("filetype", "http", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

local function run_request(ctx, item, action)
  ctx:close()
  goto_request(requests[item.label])
  Ui.open()
end

local function run_all_requests(ctx)
  ctx:close()
  Ui.open_all()
end

local maps = {
  r = { run_request, "Run" },
  a = { run_all_requests, "Run all" },
}

local open_snacks = function()
  requests, names = get_requests()

  local items = vim.iter(names):fold({}, function(acc, name)
    table.insert(acc, { text = name, label = name })
    return acc
  end)

  local keys_hint = vim.iter(maps):fold("", function(acc, key, map)
    local hint = ("  %s: %s"):format(key, map[2])
    return acc .. hint
  end)

  local keys = vim.iter(maps):fold({}, function(acc, key, map)
    acc[key] = { key, desc = map[2], mode = { "n" } }
    return acc
  end)

  local actions = vim.iter(maps):fold({}, function(acc, key, map)
    acc[key] = map[1]
    return acc
  end)

  snacks_picker {
    title = "Document Requests",
    items = items,
    actions = actions,
    matcher = { sort_empty = false },
    layout = Config.options.ui.pickers.snacks.layout,

    preview = function(ctx)
      local bufnr = ctx.picker.layout.wins.preview.buf
      set_request(bufnr, requests, ctx.item.label)
      return true
    end,

    win = {
      preview = {
        title = "Reqeuest Preview",
        wo = {
          winbar = (" "):rep(10) .. keys_hint,
          number = false,
          relativenumber = false,
          signcolumn = "no",
          sidescrolloff = 1,
        },
      },
      input = { keys = keys },
      list = { title = "Requests" },
    },

    confirm = function(ctx, item)
      ctx:close()
      goto_request(requests[item.label])
    end,
  }
end

local open_telescope = function()
  local action_state = require("telescope.actions.state")
  local actions = require("telescope.actions")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local previewers = require("telescope.previewers")
  local config = require("telescope.config").values

  requests, names = get_requests()

  pickers
    .new({}, {
      prompt_title = "Search document requests",
      results_title = "Requests",
      finder = finders.new_table {
        results = names,
      },

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          goto_request(requests[selection.value])
        end)

        return true
      end,

      previewer = previewers.new_buffer_previewer {
        title = "Request Preview",
        define_preview = function(self, entry)
          set_request(self.state.bufnr, requests, entry.value)
        end,
      },

      sorter = config.generic_sorter {},
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
