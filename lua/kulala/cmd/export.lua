local Db = require("kulala.db")
local Fs = require("kulala.utils.fs")
local Graphql = require("kulala.parser.graphql")
local Logger = require("kulala.logger")
local Parser = require("kulala.parser.document")

local lsp = vim.lsp

local M = {}

local Postman = {
  collection = {
    info = {
      name = "",
      description = "",
      schema = "https://schema.getpostman.com/json/collection/v2.1.0/",
      version = nil,
    },
    item = {}, -- item_group[] | item[]
    variable = {}, -- variable[]
  },

  item_group = {
    id = nil,
    name = "",
    description = "",
    item = {}, -- item_group[] | item[]
    variable = {}, -- variable[]
  },

  item = {
    id = nil,
    name = "",
    description = nil,
    request = {}, -- string | request
    event = {}, -- event[]
    response = {}, -- response[] | response
  },

  event = {
    listen = "", -- "prerequest"|"test"
    script = {
      exec = "", -- string | string[]
      type = "text/javascript",
    },
  },

  variable = {
    id = "",
    key = "",
    type = nil, -- "string" | "number" | "boolean" | "any"
    disabled = false,
    value = "",
  },

  request = {
    description = "",
    url = "", -- string | url
    method = "", -- string
    header = {}, -- header | header[]
    body = {}, -- body
  },

  url = {
    raw = "",
    protocol = nil, -- "http" | "https"
    host = nil, -- string | string[]
    path = nil, -- string | string[]
    port = nil,
    query = {}, -- query_param[]
    hash = nil, -- string url fragment
    variable = nil, -- variable[]
  },

  query_param = { key = "", value = "", disabled = false },
  header = { key = "", value = "", disabled = false },

  body = {
    mode = "", -- string "raw | urlencoded | formdata | file | graphql",
    raw = "", -- string
    urlencoded = {}, -- urlencoded[]
    formdata = {},
    file = {},
    graphql = {},
    disabled = false,
    options = {},
  },

  urlencoded = { key = "", value = "", disabled = false },

  formdata = {
    type = "String", -- "String" | "file"
    key = "", -- "image"
    value = "",
    src = nil, -- for type "file"
    disabled = false,
    contentType = "", -- Content-Type header of the entity
  },

  file = { src = "" },
  graphql = { query = "", variables = {} },
}

local function new(tbl, params)
  return vim.tbl_deep_extend("force", tbl, params or {})
end

local function get_url(request)
  -- return new(Postman.url, { raw = request.url })
  return request.url
end

local function get_headers(request)
  local headers = {}
  vim.iter(request.headers):each(function(key, value)
    local header = new(Postman.header, { key = key, value = value })
    table.insert(headers, header)
  end)
  return headers
end

local function get_body(request)
  -- local a = Graphql.get_json(request.body)

  return new(Postman.body, { mode = "raw", raw = request.body })
end

local function get_scripts(request)
  local events = {}

  local scripts = request.scripts.pre_request
  if #scripts.inline > 0 then
    local event = new(Postman.event, {
      listen = "prerequest",
      script = { exec = table.concat(scripts.inline, "\n") }, -- get file
    })

    table.insert(events, event)
  end

  scripts = request.scripts.post_request
  if #scripts.inline > 0 then
    local event = new(Postman.event, {
      listen = "test",
      script = { exec = table.concat(scripts.inline, "\n") }, -- get file
    })

    table.insert(events, event)
  end

  return events
end

local function to_postman(path, export_type)
  local files = export_type == "folder" and Fs.find_all_http_files(path) or { path }

  local collection = new(Postman.collection, {
    info = {
      name = vim.fn.fnamemodify(path, ":t:r"),
      description = "Exported from Kulala: " .. path,
    },
  })

  vim.iter(files):each(function(path)
    local lines = vim.split(Fs.read_file(path) or "", "\n")

    local variables, requests = Parser.get_document(lines)
    if #requests == 0 then return end

    local item_group = new(Postman.item_group, {
      name = vim.fn.fnamemodify(path, ":t:r"),
      description = "Kulala Export: " .. path,
    })

    vim.iter(requests):each(function(request)
      local item = new(Postman.item, {
        id = request.start_line,
        name = request.name,
        event = get_scripts(request),
      })

      item.request = new(Postman.request, {
        description = table.concat(request.comments, "\n"),
        method = request.method,
        url = get_url(request),
        header = get_headers(request),
        body = get_body(request),
      })

      table.insert(item_group.item, item)
    end)

    table.insert(collection.item, item_group)

    vim.iter(variables):each(function(key, value)
      local var = new(Postman.variable, { id = key, key = key, value = value })
      table.insert(collection.variable, var)
    end)
  end)

  return collection
end

--- Exports current buffer|file|folder to Postman collection
---@param action lsp.CodeAction|string|nil
M.export_requests = function(action)
  local buf = vim.api.nvim_get_current_buf()
  local bufname = action or vim.api.nvim_buf_get_name(buf)

  local export_type, path

  if type(action) == "string" and vim.fn.isdirectory(action) == 1 then
    export_type = "folder"
    path = action
  elseif type(action) == "table" and action.command == "export_folder" then
    export_type = "folder"
    path = vim.fn.fnamemodify(bufname, ":p:h")
  else
    export_type = "file"
    path = action or bufname
  end

  local collection = to_postman(path, export_type)

  local file = vim.fn.fnamemodify(bufname, ":r") .. ".json"
  if Fs.write_json(file, collection, true, true) then Logger.info("Exported collection: " .. file) end

  return collection
end

return M

--TODO: different bodies (formdata, urlencoded, file, graphql)
--TODO: url with query params
--TODO: scripts in files
