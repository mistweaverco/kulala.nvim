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

  local win_width = vim.api.nvim_win_get_width(win_id)
  local winbar_panes = config.default_winbar_panes
  local winbar_labels = config.ui.winbar_labels

  local raw_tabs = {}
  local active_index = 1

  for i, key in ipairs(winbar_panes) do
    local label = winbar_labels[key]
    local keymap = winbar_keymaps[key]

    if label then
      local base_text = label

      if config.ui.winbar_labels_keymaps and win_width > 75 and keymaps[keymap] and keymaps[keymap][1] then
        local map = keymaps[keymap][1]
          :gsub("<[Ll]eader>", vim.g.mapleader or "%1")
          :gsub("<[Ll]ocalleader>", vim.g.maplocalleader or "%1")

        if map then base_text = base_text .. " (" .. map .. ")" end
      end

      local click_syntax = "%" .. i .. "@v:lua.require'kulala.ui.winbar'.select_winbar_tab@" .. base_text .. "%X"
      local is_selected = (view == key)

      table.insert(raw_tabs, {
        display = is_selected and "%#KulalaTabSel# " .. click_syntax or "%#KulalaTab# " .. click_syntax,
        -- length of string text + padding spaces
        length = #base_text + 2,
        selected = is_selected,
      })

      if is_selected then active_index = #raw_tabs end
    end
  end

  local available_width = win_width - 4 -- safety margin padding

  if
    config.ui.winbar_labels_keymaps
    and keymaps["Previous response"]
    and keymaps["Previous response"][1]
    and win_width > 60
  then
    available_width = available_width - (#keymaps["Previous response"][1] + #keymaps["Next response"][1] + 8)
  end

  local start_idx = active_index
  local end_idx = active_index
  local current_used_width = raw_tabs[active_index] and raw_tabs[active_index].length or 0

  while true do
    local expanded = false
    if start_idx > 1 then
      -- account for divider space or " ..."
      local next_len = raw_tabs[start_idx - 1].length + 7
      if current_used_width + next_len <= available_width then
        start_idx = start_idx - 1
        current_used_width = current_used_width + next_len
        expanded = true
      end
    end
    if end_idx < #raw_tabs then
      local next_len = raw_tabs[end_idx + 1].length + 3
      if current_used_width + next_len <= available_width then
        end_idx = end_idx + 1
        current_used_width = current_used_width + next_len
        expanded = true
      end
    end
    if not expanded then break end
  end

  local winbar_title = {}
  if start_idx > 1 then table.insert(winbar_title, "%#KulalaTab#...%*") end

  for idx = start_idx, end_idx do
    if raw_tabs[idx] then table.insert(winbar_title, raw_tabs[idx].display) end
  end

  if end_idx < #raw_tabs then table.insert(winbar_title, "%#KulalaTab# …%*") end

  if
    config.ui.winbar_labels_keymaps
    and keymaps["Previous response"]
    and keymaps["Previous response"][1]
    and win_width > 60
  then
    table.insert(winbar_title, "%#KulalaTab# <- " .. keymaps["Previous response"][1] .. " %*")
    table.insert(winbar_title, "%#KulalaTab# " .. keymaps["Next response"][1] .. " -> %*")
  end

  local value = table.concat(winbar_title, " ")
  vim.api.nvim_set_option_value("winbar", value, { win = win_id })

  M.winbar_sethl()
end

return M
