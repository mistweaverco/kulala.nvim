local FS = require("kulala.utils.fs")
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local STRING_UTILS = require("kulala.utils.string")
local M = {}

local random = math.random
math.randomseed(os.time())

---Generate a random uuid
---@return string
local function uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  ---@diagnostic disable-next-line redundant-return-value
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
    return string.format("%x", v)
  end)
end

local previous_response_body = function()
  local previous_response = FS.read_file(GLOBALS.BODY_FILE)
  if not previous_response then
    return ""
  end
  return STRING_UTILS.trim(previous_response)
end

---Retrieve all dynamic variables from both rest.nvim and the ones declared by
---the user on his configuration
---@return { [string]: fun():string }[] An array-like table of tables which contains dynamic variables definition
function M.retrieve_all()
  local user_variables = CONFIG.get().custom_dynamic_variables or {}
  local rest_variables = {
    ["$uuid"] = uuid,
    ["$date"] = function()
      return os.date("%Y-%m-%d")
    end,
    ["$timestamp"] = os.time,
    ["$previousResponseBody"] = previous_response_body,
    ["$randomInt"] = function()
      return math.random(0, 1000)
    end,
  }

  return vim.tbl_deep_extend("force", rest_variables, user_variables)
end

---Look for a dynamic variable and evaluate it
---@param name string The dynamic variable name
---@return string|nil The dynamic variable value or `nil` if the dynamic variable was not found
function M.read(name)
  local vars = M.retrieve_all()
  if not vim.tbl_contains(vim.tbl_keys(vars), name) then
    ---@diagnostic disable-next-line need-check-nil
    vim.notify("The dynamic variable '" .. name .. "' was not found. Maybe it's written wrong or doesn't exist?")
    return nil
  end

  return vars[name]()
end

return M
