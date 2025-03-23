local CONFIG = require("kulala.config")
local Logger = require("kulala.logger")
local Oauth = require("kulala.parser.oauth")
local M = {}

math.randomseed(os.time())

---Generate a random uuid
---@return string
local function uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  ---@diagnostic disable-next-line redundant-return-value
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

local function auth_token(name)
  local config = name:match("^%$auth.token%(['\"](.+)['\"]%)")
  return Oauth.get_token(config)
end

---Retrieve all dynamic variables from both rest.nvim and the ones declared by
---the user on his configuration
---@return { [string]: fun():string }[] #An array-like table of tables which contains dynamic variables definition
function M.retrieve_all()
  local user_variables = CONFIG.get().custom_dynamic_variables or {}
  local rest_variables = {
    ["$uuid"] = uuid,
    ["$date"] = function()
      return os.date("%Y-%m-%d")
    end,
    ["$timestamp"] = os.time,
    ["$randomInt"] = function()
      return math.random(0, 9999999)
    end,
  }

  return vim.tbl_deep_extend("force", rest_variables, user_variables)
end

---Look for a dynamic variable and evaluate it
---@param name string The dynamic variable name
---@return string|nil The dynamic variable value or `nil` if the dynamic variable was not found
function M.read(name)
  local vars = M.retrieve_all()
  if name:match("^%$auth.token") then return auth_token(name) end

  if not vim.tbl_contains(vim.tbl_keys(vars), name) then
    return Logger.warn(
      "The dynamic variable '" .. name .. "' was not found. Maybe it's written wrong or doesn't exist?"
    )
  end

  return vars[name]()
end

return M
