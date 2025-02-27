local CONFIG = require("kulala.config")
local M = {}

local winbar_info = {
  body = {
    desc = "Body (B)",
  },
  headers = {
    desc = "Headers (H)",
  },
  headers_body = {
    desc = "All (A)",
  },
  verbose = {
    desc = "Verbose (V)",
  },
  script_output = {
    desc = "Script Output (O)",
  },
  stats = {
    desc = "Stats (S)",
  },
  report = {
    desc = "Report (R)",
  },
}

---set winbar highlight
M.winbar_sethl = function()
  vim.api.nvim_set_hl(0, "KulalaTab", { link = "TabLine" })
  vim.api.nvim_set_hl(0, "KulalaTabSel", { link = "TabLineSel" })
end

---@param win_id integer|nil Window id
---@param view string Body or headers
M.toggle_winbar_tab = function(_, win_id, view)
  local config = CONFIG.get()
  local keymaps = config.kulala_keymaps

  if not (win_id and config.winbar) then return end

  local winbar = config.default_winbar_panes
  local winbar_title = {}

  for _, key in ipairs(winbar) do
    local info = winbar_info[key]

    if info ~= nil then
      local desc = info.desc .. " %*"

      if view == key then
        desc = "%#KulalaTabSel# " .. desc
      else
        desc = "%#KulalaTab# " .. desc
      end

      table.insert(winbar_title, desc)
    end
  end

  if keymaps and keymaps["Previous response"] then
    table.insert(winbar_title, "<- " .. keymaps["Previous response"][1])
    table.insert(winbar_title, keymaps["Next response"][1] .. " ->")
  end

  local value = table.concat(winbar_title, " ")
  vim.api.nvim_set_option_value("winbar", value, { win = win_id })

  M.winbar_sethl()
end

return M
