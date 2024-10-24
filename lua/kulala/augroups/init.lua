local Config = require("kulala.config")
local Float = require("kulala.ui.float")

local TS = require("kulala.parser.treesitter")
local DB = require("kulala.db")
local ENV_PARSER = require("kulala.parser.env")

local VV_NS_NAME = "virtual_variable_text_namespace"
local M = {
  show_virtual_variable_text = Config.get().show_variable_info_text == "virtual",
}

local show_variable_info_text = function()
  local line = vim.api.nvim_get_current_line()
  local default_headers = nil
  if DB.find_unique("http_client_env_shared") then
    local headers = DB.find_unique("http_client_env_shared")["$default_headers"]
    if headers then
      default_headers = headers
    end
  end
  local variables = vim.tbl_extend(
    "force",
    TS == nil and {} or TS.get_document_variables() or {},
    ENV_PARSER.get_env() or {},
    default_headers or {}
  )
  if vim.tbl_isempty(variables) then
    return nil
  end

  -- get variable under cursor
  -- a variable is a string that starts with two {{ and ends with two }}
  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_col = cursor[2]
  local end_col = cursor[2]
  while start_col > 0 and line:sub(start_col, start_col) ~= "{" do
    start_col = start_col - 1
  end
  while end_col < #line and line:sub(end_col, end_col) ~= "}" do
    end_col = end_col + 1
  end
  if start_col == 0 or end_col == #line then
    return nil
  end
  local variable = line:sub(start_col + 1, end_col - 1)
  local variable_value = variables[variable]
  if not variable_value then
    variable_value = "{{" .. variable .. "}}"
  end
  local max_len = Config.get().virtual_variable_max_length or 100
  if #variable_value > max_len then
    variable_value = variable_value:sub(1, max_len) .. "..."
  end
  return Float.create({
    contents = { variable_value },
    position = "cursor",
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
  local max_len = Config.get().virtual_variable_max_length or 100

  local default_headers = nil
  if DB.find_unique("http_client_env_shared") then
    local headers = DB.find_unique("http_client_env_shared")["$default_headers"]
    if headers then
      default_headers = headers
    end
  end

  local variables = vim.tbl_extend(
    "force",
    TS == nil and {} or TS.get_document_variables() or {},
    ENV_PARSER.get_env() or {},
    default_headers or {}
  )

  for lineno, line in ipairs(lines) do
    if line ~= nil and line:match("%S") ~= nil then
      for start_idx, match in line:gmatch("()(" .. pattern .. ")()") do
        local label = match:gsub("{{", ""):gsub("}}", "")
        local value = variables[label]
        if value ~= nil then
          -- Calculate the position to place virtual text
          local end_idx = start_idx + #match - 1

          if #value > max_len then
            value = value:sub(1, max_len) .. "..."
          end
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

M.toggle_virtual_variable = function()
  M.show_virtual_variable_text = not M.show_virtual_variable_text

  local group_name = "kulala_virtual_variable"
  if M.show_virtual_variable_text then
    add_virtual_variable_text()
    vim.api.nvim_create_augroup(group_name, { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
      group = group_name,
      callback = add_virtual_variable_text,
    })
  else
    local ns_id = vim.api.nvim_create_namespace(VV_NS_NAME)
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    vim.api.nvim_clear_autocmds({ group = group_name })
  end
end

M.setup = function()
  local type = Config.get().show_variable_info_text
  if type == "float" then
    local augroup = vim.api.nvim_create_augroup("kulala_show_float_variable_info_text", { clear = true })
    local float_win_id = nil
    local timer = nil
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = augroup,
      callback = function()
        if float_win_id then
          vim.api.nvim_win_close(float_win_id, true)
          float_win_id = nil
        end
        if timer then
          vim.fn.timer_stop(timer)
          timer = nil
        end
        vim.schedule(function()
          timer = vim.fn.timer_start(1000, function()
            float_win_id = show_variable_info_text()
          end)
        end)
      end,
    })
  elseif type == "virtual" then
    M.toggle_virtual_variable()
  end
end

return M
