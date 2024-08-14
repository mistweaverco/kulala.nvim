local UICallbacks = require("kulala.ui.callbacks")
local CONFIG = require("kulala.config")
local M = {}

---set winbar highlight
M.winbar_sethl = function()
  vim.api.nvim_set_hl(0, "KulalaTab", { link = "TabLine" })
  vim.api.nvim_set_hl(0, "KulalaTabSel", { link = "TabLineSel" })
end

---set local key mapping
---@param buf integer|nil Buffer
M.winbar_set_key_mapping = function(buf)
  if buf then
    vim.keymap.set("n", "B", function()
      require("kulala.ui").toggle_headers()
    end, { silent = true, buffer = buf })
    vim.keymap.set("n", "H", function()
      require("kulala.ui").toggle_headers()
    end, { silent = true, buffer = buf })
  end
end

---@param win_id integer|nil Window id
---@param view string Body or headers
M.toggle_winbar_tab = function(win_id, view)
  if win_id then
    if view == "body" then
      vim.api.nvim_set_option_value(
        "winbar",
        "%#KulalaTabSel# Body (B) %* %#KulalaTab# Headers (H) %* ",
        { win = win_id }
      )
    elseif view == "headers" then
      vim.api.nvim_set_option_value(
        "winbar",
        "%#KulalaTab# Body (B) %* %#KulalaTabSel# Headers (H) %* ",
        { win = win_id }
      )
    end
  end
end

---@param win_id integer|nil Window id
M.create_winbar = function(win_id)
  if win_id then
    local default_view = CONFIG.get().default_view
    M.winbar_sethl()
    M.toggle_winbar_tab(win_id, default_view)
    UICallbacks.add("on_replace_buffer", function(_, new_buffer)
      M.winbar_set_key_mapping(new_buffer)
    end)
  end
end

return M
