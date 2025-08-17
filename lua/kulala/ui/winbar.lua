local CONFIG = require("kulala.config")
local KEYMAPS = require("kulala.config.keymaps")
local UI_utils = require("kulala.ui.utils")

local M = {}

local winbar_info = {
  body = {
    id = 1,
    desc = "Body",
    keymap = "Show body",
  },
  headers = {
    id = 2,
    desc = "Headers",
    keymap = "Show headers",
  },
  headers_body = {
    id = 3,
    desc = "All",
    keymap = "Show headers and body",
  },
  verbose = {
    id = 4,
    desc = "Verbose",
    keymap = "Show verbose",
  },
  script_output = {
    id = 5,
    desc = "Script Output",
    keymap = "Show script output",
  },
  stats = {
    id = 8,
    desc = "Stats",
    keymap = "Show stats",
  },
  report = {
    id = 6,
    desc = "Report",
    keymap = "Show report",
  },
  help = {
    id = 7,
    desc = "Help",
    keymap = "Show help",
  },
}

---set winbar highlight
M.winbar_sethl = function()
  vim.api.nvim_set_hl(0, "KulalaTab", { link = "TabLine" })
  vim.api.nvim_set_hl(0, "KulalaTabSel", { link = "TabLineSel" })
end

--- Select winbar tab
---@param pane string Clicked pane
M.select_winbar_tab = function(pane)
  local default_panes = CONFIG.get().default_winbar_panes
  local func_name = "show_"..default_panes[pane]
  require("kulala.ui")[func_name]()
end

---@param win_id integer|nil Window id
---@param view string Body or headers
M.toggle_winbar_tab = function(buf, win_id, view)
  local config = CONFIG.get()
  local keymaps = type(config.kulala_keymaps) == "table" and config.kulala_keymaps or KEYMAPS.setup_kulala_keymaps(buf)

  if not (win_id and config.winbar) then return UI_utils.set_virtual_text(buf, 0, "? - help", 0, 0) end

  local winbar = config.default_winbar_panes
  local winbar_title = {}

  for _, key in ipairs(winbar) do
    local info = winbar_info[key]

    if info then
      local desc = "%" .. info.id .. "@v:lua.require'kulala.ui.winbar'.select_winbar_tab@" .. info.desc
      local map = keymaps[info.keymap]
        and keymaps[info.keymap][1]
          :gsub("<[Ll]eader>", vim.g.mapleader or "%1")
          :gsub("<[Ll]ocalleader>", vim.g.maplocalleader or "%1")

      desc = map and desc .. " (" .. map .. ")" or desc
      desc = view == key and "%#KulalaTabSel# " .. desc or "%#KulalaTab# " .. desc
      desc = desc .. " %*%X"

      table.insert(winbar_title, desc)
    end
  end

  if keymaps["Previous response"] then
    table.insert(winbar_title, "<- " .. keymaps["Previous response"][1])
    table.insert(winbar_title, keymaps["Next response"][1] .. " ->")
  end

  local value = table.concat(winbar_title, " ")
  vim.api.nvim_set_option_value("winbar", value, { win = win_id })

  M.winbar_sethl()
end

return M
