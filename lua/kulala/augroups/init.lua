local Config = require("kulala.config")
local Env = require("kulala.parser.env")
local Float = require("kulala.ui.float")
local Parser = require("kulala.parser.document")
local StringVariablesParser = require("kulala.parser.string_variables_parser")

local M = {}

local show_variable_info_text = function()
  local line = vim.api.nvim_get_current_line()
  local env = Env.get_env() or {}

  local request = Parser.get_document() or {}
  local variables = vim.tbl_extend("force", request.variables, env)

  -- get variable under cursor
  -- a variable is a string that starts with two {{ and ends with two }}
  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_col, end_col = cursor[2], cursor[2]

  while start_col > 0 and line:sub(start_col, start_col) ~= "{" do
    start_col = start_col - 1
  end

  while end_col < #line and line:sub(end_col, end_col) ~= "}" do
    end_col = end_col + 1
  end

  if start_col == 0 or end_col == #line then return end

  local variable = line:sub(start_col + 1, end_col - 1)
  local computed_variable = "{{" .. variable .. "}}"
  local variable_value = StringVariablesParser.parse(computed_variable, variables, env, true)

  return Float.create(variable_value, { relative = "cursor", border = "rounded", auto_size = true }).win
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
            float_win_id = show_variable_info_text()
          end)
        end)
      end,
    })
  end
end

return M
