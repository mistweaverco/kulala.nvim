local Config = require("kulala.config")
local Float = require("kulala.ui.float")
local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")

local M = {}

local function cursor_inside_variable_template()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_col, end_col = cursor[2], cursor[2]

  while start_col > 0 and line:sub(start_col, start_col) ~= "{" do
    start_col = start_col - 1
  end

  while end_col < #line and line:sub(end_col, end_col) ~= "}" do
    end_col = end_col + 1
  end

  if start_col == 0 or end_col == #line then return false end
  return line:sub(start_col, start_col + 1) == "{{" and line:sub(end_col - 1, end_col) == "}}"
end

local function hover_plaintext_value(hover)
  if type(hover) ~= "table" or type(hover.contents) ~= "table" then return nil end
  local contents = hover.contents
  if contents.kind ~= "plaintext" or type(contents.value) ~= "string" then return nil end
  return contents.value
end

local function hide_float(win, timer)
  if win then vim.api.nvim_win_close(win, true) end
  if timer then vim.fn.timer_stop(timer) end
end

M.setup = function()
  if Config.get().ui.show_variable_info_text == "float" then
    local augroup = vim.api.nvim_create_augroup("kulala_show_variable_info_text", { clear = true })
    local float_win_id = nil
    local timer = nil

    vim.api.nvim_create_autocmd("BufDelete", {
      group = augroup,
      callback = function()
        float_win_id, timer = hide_float(float_win_id, timer)
      end,
    })

    vim.api.nvim_create_autocmd("CursorMoved", {
      group = augroup,
      callback = function()
        if vim.bo.filetype ~= "http" and vim.bo.filetype ~= "rest" then return end

        float_win_id, timer = hide_float(float_win_id, timer)

        vim.schedule(function()
          timer = vim.fn.timer_start(1000, function()
            if not cursor_inside_variable_template() then return end
            KULALA_CORE.lsp_hover_async(0, function(hover, err)
              if err or not hover then return end
              local value = hover_plaintext_value(hover)
              if not value or value == "" then return end
              float_win_id = Float.create(value, {
                relative = "cursor",
                border = "rounded",
                auto_size = true,
              }).win
            end)
          end)
        end)
      end,
    })
  end
end

return M
