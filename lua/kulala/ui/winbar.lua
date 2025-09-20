local CONFIG = require("kulala.config")
local KEYMAPS = require("kulala.config.keymaps")
local UI_utils = require("kulala.ui.utils")

local M = {}

local winbar_keymaps = {
  body = "Show body",
  headers = "Show headers",
  headers_body = "Show headers and body",
  verbose = "Show verbose",
  script_output = "Show script output",
  stats = "Show stats",
  report = "Show report",
  help = "Show help",
}

---set winbar highlight
M.winbar_sethl = function()
  vim.api.nvim_set_hl(0, "KulalaTab", { link = "TabLine" })
  vim.api.nvim_set_hl(0, "KulalaTabSel", { link = "TabLineSel" })
end

M.select_winbar_tab = function(pane)
  local default_panes = CONFIG.get().default_winbar_panes
  local func_name = "show_" .. default_panes[pane]
  require("kulala.ui")[func_name]()
end

---@param win_id integer|nil Window id
---@param view string Body or headers
M.toggle_winbar_tab = function(buf, win_id, view)
  local config = CONFIG.get()
  local keymaps = type(config.kulala_keymaps) == "table" and config.kulala_keymaps or KEYMAPS.setup_kulala_keymaps(buf)

  if not (win_id and config.winbar) then return UI_utils.set_virtual_text(buf, 0, "? - help", 0, 0) end

  local winbar_panes = config.default_winbar_panes
  local winbar_labels = config.ui.winbar_labels
  local winbar_title = {}

  for i, key in ipairs(winbar_panes) do
    local label = winbar_labels[key]
    local keymap = winbar_keymaps[key]

    if label then
      local desc = "%" .. i .. "@v:lua.require'kulala.ui.winbar'.select_winbar_tab@" .. label

      if config.ui.winbar_labels_keymaps then
        local map = keymaps[keymap]
          and keymaps[keymap][1]
            :gsub("<[Ll]eader>", vim.g.mapleader or "%1")
            :gsub("<[Ll]ocalleader>", vim.g.maplocalleader or "%1")

        desc = map and desc .. " (" .. map .. ")" or desc
      end

      desc = view == key and "%#KulalaTabSel# " .. desc or "%#KulalaTab# " .. desc
      desc = desc .. " %*%X"

      table.insert(winbar_title, desc)
    end
  end

  if config.ui.winbar_labels_keymaps and keymaps["Previous response"] then
    table.insert(winbar_title, "<- " .. keymaps["Previous response"][1])
    table.insert(winbar_title, keymaps["Next response"][1] .. " ->")
  end

  local value = table.concat(winbar_title, " ")
  vim.api.nvim_set_option_value("winbar", value, { win = win_id })

  M.winbar_sethl()
end

return M
