local CONFIG = require("kulala.config")
local FS = require("kulala.utils.fs")
local GLOBAL = require("kulala.globals")
local Table = require("kulala.utils.table")

local M = {}

M.data = nil
M.session = {}

---@class Response
---@field id string
---@field name string -- name of the request
---
---@field url string -- request url
---@field method string -- request method
---@field request { headers_tbl: table, body: string } -- request
---
---@field status boolean -- status of the request
---@field code number -- request command exit code
---@field response_code number -- http response code
---
---@field duration number -- duration of the request
---@field time number -- time of the request
---
---@field body string -- body of the response
---@field body_raw string -- body of the response (unaltered)
---@field json table -- json response
---@field filter string|nil -- jq filter if applied
---
---@field headers string -- headers of the response
---@field headers_tbl table -- parsed headers of the response
---
---@field cookies table -- received cookies
---
---@field errors string -- errors of the request
---@field stats table|string -- stats of the request
---
---@field script_pre_output string
---@field script_post_output string
---
---@field assert_output table
---@field assert_status boolean
---
---@field file string -- path of the file of the request
---@field buf number
---@field buf_name string
---@field line number

---@class GlobalData
---@field responses Response[] -- history of responses
---@field current_response_pos number -- index of current response shown in UI
---@field previous_response_pos number -- index of previous response shown in UI
---@field replay Request|nil -- previous request stored for replay
M.global_data = {
  responses = {},
  current_response_pos = 0,
  previous_response_pos = 0,
  replay = nil,
}

M.current_buffer = nil
M.current_request = nil

---Gets DB.current_buffer or if it does not exist, then sets it to current buffer
---@return number
M.get_current_buffer = function()
  local buf = M.current_buffer
  return vim.api.nvim_buf_is_valid(buf or -1) and buf or M.set_current_buffer()
end

---Sets DB.current_buffer to provided buffer_id or to current buffer
---@param id number|nil
M.set_current_buffer = function(id)
  M.current_buffer = id and id or vim.api.nvim_get_current_buf()
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

---@return GlobalData
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

local mt_settings

mt_settings = {
  __index = {
    --- @param self table,
    --- @param update table <string, any>
    --- @return table
    write = function(self, update)
      Table.merge("force", self, update or {})
      FS.write_json(GLOBAL.SETTINGS_FILE, vim.deepcopy(self))
      return self
    end,
  },

  create = function()
    FS.ensure_dir_exists(vim.fn.fnamemodify(GLOBAL.SETTINGS_FILE, ":h"))
    return FS.write_json(GLOBAL.SETTINGS_FILE, {}) and {}
  end,

  read = function(self)
    local settings = FS.read_json(GLOBAL.SETTINGS_FILE) or self:create()
    return setmetatable(settings, mt_settings)
  end,
}

M.settings = mt_settings:read()

return M
