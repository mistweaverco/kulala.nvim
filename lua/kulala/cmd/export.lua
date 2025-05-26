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
    variable = nil, -- variable[]
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
    query = nil, -- query_param[]
    hash = nil, -- string url fragment
    variable = nil, -- variable[]
  },

  query_param = { key = "", value = "", disabled = false },
  header = { key = "", value = "", disabled = false },

  body = {
    mode = "", -- string "raw | urlencoded | formdata | file | graphql",
    raw = "", -- string
    urlencoded = nil, -- urlencoded[]
    formdata = nil,
    file = nil,
    graphql = nil,
    disabled = false,
    options = nil,
  },

  urlencoded = { key = "", value = "", disabled = false },

  formdata = {
    type = "", -- "text"|"file"
    src = "", -- string|string[]|nil
    key = "",
    value = "",
    disabled = false,
    contentType = "", -- Content-Type header of the entity
  },

  file = {
    src = "", -- file name
    content = "", -- file content
  },

  graphql = { query = "", variables = {} },
}

local function new(tbl, params)
  tbl = vim.deepcopy(tbl)
  return vim.tbl_deep_extend("force", tbl, params or {})
end

local function get_url(request)
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
  if request.method == "GRAPHQL" then
    request.method = "POST" -- Postman expects POST for GraphQL requests

    local _, json = Graphql.get_json(request.body)
    return new(Postman.body, { mode = "graphql", graphql = json or {} })
  end

  return new(Postman.body, { mode = "raw", raw = request.body })
end

local function get_script(scripts, type)
  local events = {}

  if #scripts.inline > 0 then
    local event = new(Postman.event, {
      listen = type,
      script = { name = "inline", exec = scripts.inline },
    })
    table.insert(events, event)
  end

  vim.iter(scripts.files):each(function(file)
    local script = Fs.read_file(file)
    if not script then return end

    local event = new(Postman.event, {
      listen = type,
      script = { name = file, exec = script },
    })
    table.insert(events, event)
  end)

  return events
end

local function get_scripts(request)
  local events = {}

  vim.list_extend(events, get_script(request.scripts.pre_request, "prerequest"))
  vim.list_extend(events, get_script(request.scripts.post_request, "test"))

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

    local filename = vim.fn.fnamemodify(path, ":t:r")

    local item_group = new(Postman.item_group, {
      name = filename,
      description = "Kulala Export: " .. path,
    })

    vim.iter(requests):each(function(request)
      local item = new(Postman.item, {
        id = filename .. ":" .. request.start_line,
        name = request.name,
        event = get_scripts(request),
      })

      item.request = new(Postman.request, {
        description = table.concat(request.comments, "\n"),
        url = get_url(request),
        header = get_headers(request),
        body = get_body(request),
      })

      item.request.method = request.method -- can be mutated by GRAPHQL in get_body()

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
---@param action string|nil|lsp.CodeAction
M.export_requests = function(action)
  local buf = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(buf)

  local export_type, path

  if type(action) == "string" then
    export_type = vim.fn.isdirectory(action) == 1 and "folder" or "file"
    path = action
  elseif type(action) == "table" and action.command == "export_folder" then
    export_type = "folder"
    path = vim.fn.fnamemodify(bufname, ":p:h")
  elseif not action or (type(action) == "table" and action.command == "export_file") then
    export_type = "file"
    path = bufname
  end

  local collection = to_postman(path, export_type)

  local file = vim.fn.fnamemodify(path, ":t:r") .. ".json"
  file = (export_type == "folder" and path or vim.fn.fnamemodify(path, ":p:h")) .. "/" .. file

  if Fs.write_json(file, collection, true, true) then Logger.info("Exported collection: " .. file) end

  return collection
end

return M

--TODO: different bodies (formdata, urlencoded, file)
--TODO: auth
