local CONFIG = require("kulala.config")

local M = {}

M.data = nil

---@class Response
---@field id string
---@field url string
---@field method string
---@field status number
---@field duration number
---@field time number
---@field body string
---@field headers string
---@field errors string
---@field stats string
---@field script_pre_output string
---@field script_post_output string
---@field assert_output table
---@field buf number
---@field buf_name string
---@field line number

---@class GlobalData
---@field responses Response[]
---@field current_response_pos number|nil
---@field replay Request|nil -- previous request stored for replay
M.global_data = {
  current_response_pos = nil, -- index of current response shown in UI
  previous_response_pos = nil, -- index of previous response shown in UI
  responses = {}, -- history of responses
  replay = nil,
}

M.current_buffer = nil

---Gets DB.current_buffer or if it does not exist, then sets it to current buffer
---@return number
M.get_current_buffer = function()
  local buf = M.current_buffer
  return vim.fn.bufexists(buf) > 0 and buf or M.set_current_buffer()
end

---Sets DB.current_buffer to provided buffer_id or to current buffer
---@param id number|nil
M.set_current_buffer = function(id)
  M.current_buffer = id and id or vim.fn.bufnr()
  return M.current_buffer
end

local function default_data()
  return {
    selected_env = nil, -- string - name of selected env
    http_client_env = nil, -- table of envs from http-client.env.json
    http_client_env_shared = nil, -- table of base env values which should be applied to all requests
    env = {}, -- table of envs from document sources
    scope_nr = nil, -- number - buffer number of the current scope
  }
end

local function get_current_scope_nr()
  if CONFIG.get().environment_scope == "b" then
    return M.get_current_buffer()
  elseif CONFIG.get().environment_scope == "g" then
    return 0
  end
end

local function load_data()
  if CONFIG.get().environment_scope == "b" then
    local buf = M.get_current_buffer()
    local kulala_data = buf and vim.b[buf].kulala_data
    M.data = kulala_data and kulala_data or default_data()
  elseif CONFIG.get().environment_scope == "g" then
    -- keep in lua only
    if not M.data then M.data = default_data() end
  end
  M.data.scope_nr = get_current_scope_nr()
end

local function save_data()
  if CONFIG.get().environment_scope == "b" then
    if vim.fn.bufexists(M.data.scope_nr) > 0 then vim.b[M.data.scope_nr].kulala_data = M.data end
  elseif CONFIG.get().environment_scope == "g" then
    -- keep in lua only
  end
end

M.global_find_many = function()
  return M.global_data
end

M.global_find_unique = function(key)
  return M.global_data[key]
end

--@return GlobalData
M.global_update = function()
  return M.global_data
end

M.find_many = function()
  if not M.data or not M.data.scope_nr then
    load_data()
  elseif M.data.scope_nr ~= get_current_scope_nr() then
    save_data()
    load_data()
  end
  return M.data
end

M.update = function()
  return M.find_many()
end

M.find_unique = function(key)
  return M.find_many()[key]
end

return M
