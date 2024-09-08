local VV_GROUP_NAME = "kulala_virtual_variable"
local VV_NS_NAME = "virtual_variable_text_namespace"
local NS = vim.api.nvim_create_namespace("kulala_inlay_hints")
local TS = require("kulala.parser.treesitter")
local DB = require("kulala.db")
local ENV_PARSER = require("kulala.parser.env")
local CONFIG = require("kulala.config")

local M = {
  show_virtual_variable_text = CONFIG.get().show_virtual_variable_text,
}

M.get_current_line_number = function()
  local linenr = vim.api.nvim_win_get_cursor(0)[1]
  return linenr
end

M.clear = function()
  vim.api.nvim_buf_clear_namespace(0, NS, 0, -1)
end

M.clear_if_marked = function(bufnr, linenr)
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, NS, { linenr - 1, 0 }, { linenr - 1, -1 }, {})
  if #extmarks > 0 then
    local extmark_id = extmarks[1][1]
    vim.api.nvim_buf_del_extmark(bufnr, NS, extmark_id)
  end
end

M.show_loading = function(self, linenr)
  M.show(CONFIG.get().icons.inlay.loading, linenr)
end

M.show_error = function(self, linenr)
  M.show(CONFIG.get().icons.inlay.error, linenr)
end

M.show_done = function(self, linenr, elapsed_time)
  local icon = ""
  if string.len(CONFIG.get().icons.inlay.done) > 0 then
    icon = CONFIG.get().icons.inlay.done .. " "
  end
  M.show(icon .. elapsed_time, linenr)
end

M.show = function(t, linenr)
  local bufnr = vim.api.nvim_get_current_buf()
  M.clear_if_marked(bufnr, linenr)
  vim.api.nvim_buf_set_extmark(bufnr, NS, linenr - 1, 0, {
    virt_text = { { t } },
  })
end

-- Function to add virtual text to patterns like {{host}}
local add_virtual_variable_text = function()
  if (M.show_virtual_variable_text or false) == false then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local ns_id = vim.api.nvim_create_namespace(VV_NS_NAME)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local pattern = "{{(.-)}}"

  local variables = vim.tbl_extend(
    "force",
    TS.get_document_variables() or {},
    ENV_PARSER.get_env() or {},
    DB.data.http_client_env_base["DEFAULT_HEADERS"] or {}
  )

  for lineno, line in ipairs(lines) do
    if line ~= nil and line:match("%S") ~= nil then
      for start_idx, match in line:gmatch("()(" .. pattern .. ")()") do
        local label = match:gsub("{{", ""):gsub("}}", "")
        local value = variables[label]
        if value ~= nil then
          -- Calculate the position to place virtual text
          local end_idx = start_idx + #match - 1

          -- Add virtual text before the closing braces of the match
          vim.api.nvim_buf_set_extmark(bufnr, ns_id, lineno - 1, end_idx - 2, {
            virt_text = { { ":" .. value, "Comment" } }, -- You can change the highlight group "Comment" as needed
            virt_text_pos = "inline",
          })
        end
      end
    end
  end
end

M.clear_virtual_variable_text = function()
  local ns_id = vim.api.nvim_create_namespace(VV_NS_NAME)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  vim.api.nvim_clear_autocmds({ group = VV_GROUP_NAME })
end

M.toggle_virtual_variable = function()
  M.show_virtual_variable_text = not M.show_virtual_variable_text

  if M.show_virtual_variable_text then
    add_virtual_variable_text()
    vim.api.nvim_create_augroup(VV_GROUP_NAME, { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
      group = VV_GROUP_NAME,
      pattern = "*.(http|rest)",
      callback = add_virtual_variable_text,
    })
  else
    M.clear_virtual_variable_text()
  end
end

return M
