local CONFIG = require("kulala.config")
local KEYMAPS = require("kulala.config.keymaps")
local UI_utils = require("kulala.ui.utils")

local M = {}

local winbar_info = {
  body = {
    desc = "Body",
    keymap = "Show body",
  },
  headers = {
    desc = "Headers",
    keymap = "Show headers",
  },
  headers_body = {
    desc = "All",
    keymap = "Show headers and body",
  },
  verbose = {
    desc = "Verbose",
    keymap = "Show verbose",
  },
  script_output = {
    desc = "Script Output",
    keymap = "Show script output",
  },
  stats = {
    desc = "Stats",
    keymap = "Show stats",
  },
  report = {
    desc = "Report",
    keymap = "Show report",
  },
  help = {
    desc = "Help",
    keymap = "Show help",
  },
}

---set winbar highlight
M.winbar_sethl = function()
  vim.api.nvim_set_hl(0, "KulalaTab", { link = "TabLine" })
  vim.api.nvim_set_hl(0, "KulalaTabSel", { link = "TabLineSel" })
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
      local desc = info.desc
      desc = keymaps[info.keymap] and desc .. " (" .. keymaps[info.keymap][1] .. ")" or desc
      desc = view == key and "%#KulalaTabSel# " .. desc or "%#KulalaTab# " .. desc
      desc = desc .. " %*"

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
