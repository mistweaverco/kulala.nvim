local Config = require("kulala.config")
local Db = require("kulala.db")
local Fs = require("kulala.utils.fs")
local Globals = require("kulala.globals")
local Logger = require("kulala.logger")
local Table = require("kulala.utils.table")

local M = {}

local script_env = {}
local script_output = {
  pre_request = "",
  post_request = "",
  assert_output = {
    status = true,
    results = {},
  },
}

local function get_nested_path(key)
  return vim
    .iter(vim.split(key, "[%.%[%]]"))
    :map(function(v)
      return v and v ~= "" and (tonumber(v) and tonumber(v) or v) or nil
    end)
    :totable()
end

local function get_response(_, name)
  return vim.iter(Db.global_update().responses):rfind(function(response)
    return response.name == name
  end) or {}
end

local assert = {
  test_suit = nil,
  test = function(name, fn)
    script_env.assert.test_suit = name
    fn()
    script_env.assert.test_suit = nil
  end,
  is_true = function(value, message)
    local status = value == true
    script_env.assert.save(status, message, true, status)
  end,
  is_false = function(value, message)
    local status = value == false
    script_env.assert.save(status, message, false, not status)
  end,
  same = function(value, expected, message)
    local status = value == expected
    script_env.assert.save(status, message, expected, value)
  end,
  has_string = function(value, expected, message)
    local status = value:find(expected, 1, true)
    value = #value > 50 and value:sub(1, 50) .. "..." or value
    script_env.assert.save(status, message, expected, value)
  end,
  response_has = function(key, expected, message)
    local value = vim.tbl_get(script_env.response.json, unpack(get_nested_path(key)))
    local status = value == expected
    script_env.assert.save(status, message, expected, vim.inspect(value))
  end,
  headers_has = function(key, expected, message)
    local value = script_env.response.headers_tbl[key]
    local status = value == expected
    script_env.assert.save(status, message, expected, value)
  end,
  body_has = function(expected, message)
    local value = script_env.response.body
    script_env.assert.has_string(value, expected, message)
  end,
  json_has = function(key, expected, message)
    local value = vim.tbl_get(script_env.response.json, unpack(get_nested_path(key)))
    local status = value == expected
    script_env.assert.save(status, message, expected, vim.inspect(value))
  end,
}

setmetatable(assert, {
  __call = function(_, value, message)
    assert.is_true(value, message)
  end,
  __index = {
    save = function(status, message, expected, value)
      local name = script_env.assert.test_suit or ""

      message = message or ("Assertion " .. (status and "succeeded" or "failed"))
      message = message .. ': expected: "' .. tostring(expected) .. '", got: "' .. tostring(value) .. '"'

      script_env.output.assert_output.status = script_output.assert_output.status and status
      table.insert(script_env.output.assert_output.results, { name = name, message = message, status = status })
    end,
  },
})

local client = {
  log = function(msg)
    msg = vim.inspect(msg)
    script_env.output[script_env.type] = script_env.output[script_env.type] .. msg .. "\n"
    _ = not Config.options.ui.disable_script_print_output and Logger.info(msg, { title = "Kulala Lua Script Output" })
  end,
  global = {},
  responses = setmetatable({}, { __index = get_response }),
  test = function(name, fn)
    assert.test(name, fn)
  end,
  assert = assert,
  clear_all = function()
    Table.remove_keys(script_env.client.global, vim.tbl_keys(script_env.client.global))
  end,
}

local request = function()
  local environment = setmetatable(Fs.read_json(Fs.get_request_scripts_variables_file_path()) or {}, {
    __index = function(t, k)
      return rawget(t, k) or script_env.request._environment[k]
    end,
    __call = function()
      return vim.tbl_extend("force", script_env.request._environment, script_env.request.environment)
    end,
  })

  return {
    environment = environment,
    variables = environment,

    skip = function()
      script_env.request.environment["__skip_request"] = "true"
    end,
    replay = function()
      script_env.request.environment["__replay_request"] = "true"
    end,
    iteration = function()
      return script_env.request.environment["__iteration"]
    end,
  }
end

local function set_script_env(type, _request, _response)
  script_env.type = type
  script_env.output = vim.deepcopy(script_output)
  script_env.output.assert_output = Fs.read_json(Globals.ASSERT_OUTPUT_FILE) or script_env.output.assert_output

  script_env.client = client
  script_env.client.global = Fs.read_json(Fs.get_global_scripts_variables_file_path()) or {}

  script_env.request = _request or {}
  script_env.request._environment = _request.environment -- make a copy of the original environment
  script_env.request.environment = nil -- clear the environment, so only new and modified variables are stored

  script_env.response = _response or {}
  script_env.assert = assert

  setmetatable(script_env, { __index = _G })
  setmetatable(script_env.request, { __index = request() })
end

local function restore_script_env()
  script_env.request.environment = script_env.request._environment
  script_env.request._environment = nil
  setmetatable(script_env.request, nil)
end

local function eval(script, script_type)
  local fn, errors = load(script, script_type, "t", script_env)
  if errors then return Logger.error("Error loading " .. script_type .. errors) end

  local status, result = xpcall(fn, debug.traceback)
  if not status then return Logger.error("Error executing " .. script_type .. result) end

  return status
end

---@param type "pre_request" | "post_request"
---@param scripts ScriptData
---@param _request Request
---@param _response Response|nil
M.run = function(type, scripts, _request, _response)
  local status = false
  local inline = table.concat(scripts.inline, "\n")

  set_script_env(type, _request, _response)

  status = #inline > 0 and scripts.priority == "inline" and eval(inline, "inline script") or status

  vim.iter(scripts.files):each(function(path)
    local script = Fs.read_file(path)
    if not script then return Logger.error("Error reading script file " .. path) end

    status = eval(script, "file script") or status
  end)

  status = #inline > 0 and scripts.priority == "files" and eval(inline, "inline script") or status

  Fs.write_json(Fs.get_request_scripts_variables_file_path(), script_env.request.environment)
  Fs.write_json(Fs.get_global_scripts_variables_file_path(), script_env.client.global)

  restore_script_env()

  _ = type == "pre_request" and Fs.write_file(Globals.SCRIPT_PRE_OUTPUT_FILE, script_env.output.pre_request)
  _ = type == "post_request" and Fs.write_file(Globals.SCRIPT_POST_OUTPUT_FILE, script_env.output.post_request)

  _ = #script_env.output.assert_output.results > 0
    and Fs.write_json(Globals.ASSERT_OUTPUT_FILE, script_env.output.assert_output, false, true)

  return status
end

return M
