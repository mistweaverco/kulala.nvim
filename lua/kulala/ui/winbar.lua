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
}

---set winbar highlight
M.winbar_sethl = function()
  vim.api.nvim_set_hl(0, "KulalaTab", { link = "TabLine" })
  vim.api.nvim_set_hl(0, "KulalaTabSel", { link = "TabLineSel" })
end

---@param win_id integer|nil Window id
---@param view string Body or headers
M.toggle_winbar_tab = function(_, win_id, view)
  if not (win_id and CONFIG.get().winbar) then
    return
  end

  local winbar = CONFIG.get().default_winbar_panes
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

  table.insert(winbar_title, "<- [")
  table.insert(winbar_title, "] ->")

  local value = table.concat(winbar_title, " ")
  vim.api.nvim_set_option_value("winbar", value, { win = win_id })

  M.winbar_sethl()
end

return M
