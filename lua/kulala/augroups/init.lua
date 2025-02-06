local Config = require("kulala.config")
local Parser = require("kulala.parser")
local Float = require("kulala.ui.float")
local Db = require("kulala.db")

local M = {}

local show_variable_info_text = function()
  local line = vim.api.nvim_get_current_line()
  local db_env = Db.find_unique("env")
  if db_env == nil then
    return nil
  end
  local variables = Parser.get_document()
  if variables == nil then
    return nil
  end
  variables = vim.tbl_extend("force", variables, db_env)
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
  local computed_variable = "{{" .. variable .. "}}"
  local variable_value = variables[variable] or computed_variable
  return Float.create({
    contents = { variable_value },
    position = "cursor",
  })
end

M.setup = function()
  if Config.get().show_variable_info_text == "float" then
    local augroup = vim.api.nvim_create_augroup("kulala_show_variable_info_text", { clear = true })
    local float_win_id = nil
    local timer = nil
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = augroup,
      callback = function()
        -- if not in http or rest filetype, exit early
        -- This should not happen, when the user loads kulala only for .http or .rest buffers,
        -- but you never know, so better safe than sorry
        if vim.bo.filetype ~= "http" and vim.bo.filetype ~= "rest" then
          return
        end
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
  end
end

return M
