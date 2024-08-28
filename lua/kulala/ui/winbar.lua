local UICallbacks = require("kulala.ui.callbacks")
local CONFIG = require("kulala.config")
local M = {}

local winbar_info = {
  body = {
    desc = "Body (B)",
    action = function()
      require("kulala.ui").show_body()
    end,
    keymap = "B",
  },
  headers = {
    desc = "Headers (H)",
    action = function()
      require("kulala.ui").show_headers()
    end,
    keymap = "H",
  },
  headers_body = {
    desc = "All (A)",
    action = function()
      require("kulala.ui").show_headers_body()
    end,
    keymap = "A",
  },
  console = {
    desc = "Console (C)",
    action = function()
      require("kulala.ui").show_console()
    end,
    keymap = "C",
  },
}

local function pairsByKeys(t)
  local a = {}
  for n in pairs(t) do
    a[#a + 1] = n
  end
  table.sort(a)

  local i = 0
  return function()
    i = i + 1
    return a[i], t[a[i]]
  end
end

---set winbar highlight
M.winbar_sethl = function()
  vim.api.nvim_set_hl(0, "KulalaTab", { link = "TabLine" })
  vim.api.nvim_set_hl(0, "KulalaTabSel", { link = "TabLineSel" })
end

---set local key mapping
---@param buf integer|nil Buffer
M.winbar_set_key_mapping = function(buf)
  if buf then
    for _, value in pairs(winbar_info) do
      vim.keymap.set("n", value.keymap, function()
        value.action()
      end, { silent = true, buffer = buf })
    end
  end
end

---@param win_id integer|nil Window id
---@param view string Body or headers
M.toggle_winbar_tab = function(win_id, view)
  if win_id then
    local winbar = CONFIG.get_winbar()
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
    local value = table.concat(winbar_title, " ")
    vim.api.nvim_set_option_value("winbar", value, { win = win_id })
    -- if view == "body" then
    --   vim.api.nvim_set_option_value(
    --     "winbar",
    --     "%#KulalaTabSel# Body (B) %* %#KulalaTab# Headers (H) %* %#KulalaTab# All (A) %* %#KulalaTab# Console (C) %* ",
    --     { win = win_id }
    --   )
    -- elseif view == "headers" then
    --   vim.api.nvim_set_option_value(
    --     "winbar",
    --     "%#KulalaTab# Body (B) %* %#KulalaTabSel# Headers (H) %* %#KulalaTab# All (A) %* %#KulalaTab# Console (C) %* ",
    --     { win = win_id }
    --   )
    -- elseif view == "headers_body" then
    --   vim.api.nvim_set_option_value(
    --     "winbar",
    --     "%#KulalaTab# Body (B) %* %#KulalaTab# Headers (H) %* %#KulalaTabSel# All (A) %* %#KulalaTab# Console (C) %* ",
    --     { win = win_id }
    --   )
    -- elseif view == "console" then
    --   vim.api.nvim_set_option_value(
    --     "winbar",
    --     "%#KulalaTab# Body (B) %* %#KulalaTab# Headers (H) %* %#KulalaTab# All (A) %* %#KulalaTabSel# Console (C) %* ",
    --     { win = win_id }
    --   )
    -- end
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
