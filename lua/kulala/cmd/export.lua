local Db = require("kulala.db")
local Env = require("kulala.parser.env")
local Fs = require("kulala.utils.fs")
local Graphql = require("kulala.parser.graphql")
local Logger = require("kulala.logger")
local Parser = require("kulala.parser.document")
local Parser_utils = require("kulala.parser.utils")
local Var_parser = require("kulala.parser.string_variables_parser")

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
    auth = nil,
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

  auth = {
    type = "",
    noauth = nil,
    apikey = nil,
    awsv4 = nil,
    basic = nil,
    bearer = nil,
    digest = nil,
    edgegrid = nil,
    hawk = nil,
    ntlm = nil,
    oauth1 = nil,
    oauth2 = nil,
  },
}

local function new(tbl, params)
  tbl = vim.deepcopy(tbl)
  return vim.tbl_deep_extend("force", tbl, params or {})
end

local function get_headers(request)
  local headers = {}

  vim.iter(request.headers):each(function(key, value)
    local header = new(Postman.header, { key = key, value = value })

    -- let Postman set these headers
    if (key:lower() == "content-type" and value:lower() == "multipart/form-data") or key:lower() == "authorization" then
      return
    end

    table.insert(headers, header)
  end)

  return headers
end

local function parse_params(body)
  local params_map, params = {}, {}

  -- Handle arrays
  -- colors[]=red&colors[]=blue
  -- colors[0]=red&colors[1]=blue
  for pair in body:gmatch("([^&]+)") do
    local k, v = pair:match("^([^=]+)=?(.*)")
    if k then
      -- Handle array notation like key[] or key[0]
      local base_key = k:match("^([^%[]+)%[")
      if base_key then
        params_map[base_key] = params_map[base_key] or {}
        table.insert(params_map[base_key], v or "")
      else -- Handle simple and repeated keys like key=value&key=another_value
        if params_map[k] then
          -- Key already exists, convert to array
          if type(params_map[k]) ~= "table" then params_map[k] = { params_map[k] } end
          table.insert(params_map[k], v or "")
        else
          params_map[k] = v or ""
        end
      end
    end
  end

  for k, v in pairs(params_map) do
    -- Array value - Postman expects one entry with comma-separated values
    local value = type(v) == "table" and table.concat(v, ",") or v
    table.insert(params, new(Postman.query_param, { key = k, value = value }))
  end

  return params
end

local function get_url(request)
  local url = new(Postman.url, { raw = request.url })

  local protocol, rest = request.url:match("^([^:]+)://(.*)$")
  url.protocol = protocol or "http"

  rest = protocol and rest or request.url

  local authority, path_query_fragment = rest:match("^([^/]+)(.*)$")
  authority = authority or rest

  local host, port = authority:match("^([^:]+):(.+)$")
  url.host = host or authority
  url.port = port

  if not path_query_fragment then
    url.path = "/"
  else
    local path = path_query_fragment:match("^([^?#]*)")
    url.path = path or "/"

    local query_string = path_query_fragment:match("%?([^#]*)") or ""
    url.query = parse_params(query_string)
    url.hash = path_query_fragment:match("#(.*)$")
  end

  return url
end

-- The standard formdata format is:
-- --boundary\r\n
-- headers\r\n\r\n
-- content\r\n
-- --boundary\r\n
-- ... more parts ...
-- --boundary--\r\n
local function parse_formdata(body, boundary)
  local formdata_items, parts = {}, {}
  local escaped_boundary = ("--" .. boundary):gsub("([%.%-%+%[%]%(%)%^%$%*%?%%])", "%%%1")

  local pattern = escaped_boundary .. "\r\n(.-)\r\n" .. escaped_boundary

  local first_part = body:match(pattern) -- first part might not have a leading boundary
  if first_part then
    table.insert(parts, first_part)
    body = body:sub(2 + #boundary + #first_part)
  end

  local part = ""
  while part do
    part = body:match("\r\n" .. pattern)
    if not part then break end

    table.insert(parts, part)
    body = body:sub(4 + #boundary + #part)
  end

  for _, part in ipairs(parts) do
    local headers, content = part:match("(.-)\r\n\r\n(.*)")

    if headers and content then
      local name = headers:match('name="([^"]+)"')
      local filename = headers:match('filename="([^"]+)"')
      local content_type = headers:match("Content%-Type: ([^\r\n]+)")

      local item = new(Postman.formdata, { key = name or "", contentType = content_type or "" })

      --TODO: get file contents as value
      if filename then
        item.type = "file"
        item.src = filename
      else
        item.type = "text"
        item.value = content
      end

      table.insert(formdata_items, item)
    end
  end

  return formdata_items
end

local function request_type(request, type)
  return request.method == type or Parser_utils.contains_header(request.headers, "Content-Type", type)
end

local function get_body(request)
  local body = new(Postman.body, { mode = "raw", raw = request.body })

  if request_type(request, "GRAPHQL") then
    request.method = "POST" -- Postman expects POST for GraphQL requests

    local _, json = Graphql.get_json(request.body)

    body.mode = "graphql"
    body.graphql = json or {}
  end

  if request_type(request, "application/x-www-form-urlencoded") then
    body.mode = "urlencoded"
    body.urlencoded = parse_params(request.body) or {}
  end

  if request_type(request, "multipart/form-data") then
    local boundary

    for key, value in pairs(request.headers) do
      if key:lower() == "content-type" then
        boundary = value:match("boundary=([^;]+)")
        break
      end
    end

    body.mode = "formdata"
    body.formdata = parse_formdata(request.body, boundary)
  end

  return body
end

local function auth_type(request, type)
  return Parser_utils.contains_header(request.headers, "Authorization", type)
end

local function get_auth(request)
  local auth = new(Postman.auth)

  if auth_type(request, "basic") then
    auth.type = "basic"
    auth.basic = {}

    local header = Parser_utils.get_header_value(request.headers, "Authorization") or ""
    local user, pass = header:match("[Bb]asic ([^:]+):(.*)")

    table.insert(auth.basic, { key = "username", value = user })
    table.insert(auth.basic, { key = "password", value = pass })
  end

  if auth_type(request, "bearer") then
    auth.type = "bearer"
    auth.bearer = {}

    local header = Parser_utils.get_header_value(request.headers, "Authorization") or ""
    local token = header:match("[Bb]earer (.*)")

    table.insert(auth.bearer, { key = "token", value = token })
  end

  return auth
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

local function get_variables(request, env)
  local vars = {}

  vim.iter({ "url", "headers", "cookie", "body" }):each(function(part)
    local content = request[part]
    content = type(content) ~= "table" and content
      or vim.iter(content):fold("", function(acc, _, v)
        return acc .. v .. "\n"
      end)

    for var in content:gmatch("{{(.-)}}") do
      vars[var] = Var_parser.get_var_value(var, request.variables, env, false)
    end
  end)

  return vars
end

local function get_env(path)
  local current_buf = vim.fn.bufnr(path)
  local temp_buf = current_buf == -1 and vim.fn.bufnr(path, true)

  Db.set_current_buffer(temp_buf or current_buf)
  local env = Env.get_env() or {}

  _ = temp_buf and vim.api.nvim_buf_delete(temp_buf, { force = true })
  return env
end

local function to_postman(path, export_type)
  local files = export_type == "folder" and Fs.find_all_http_files(path) or { path }

  local collection = new(Postman.collection, {
    info = {
      name = vim.fn.fnamemodify(path, ":t:r"),
      description = "Exported from Kulala: " .. path,
    },
  })

  local env = get_env(files[1])

  vim.iter(files):each(function(path)
    local lines = vim.split(Fs.read_file(path) or "", "\n")

    local requests = Parser.get_document(lines)
    local variables = {}

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
        auth = get_auth(request),
        url = get_url(request),
        header = get_headers(request),
        body = get_body(request),
      })

      item.request.method = request.method -- can be mutated by GRAPHQL in get_body()
      table.insert(item_group.item, item)

      Parser.apply_shared_data(request.shared, request)
      variables = vim.tbl_extend("force", request.variables, get_variables(request, env))
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

  if vim.fn.isdirectory(path) + vim.fn.filereadable(path) == 0 then
    return Logger.error("Folder/File not found: " .. path)
  end

  local collection = to_postman(path, export_type)

  local file = vim.fn.fnamemodify(path, ":t:r") .. ".json"
  file = (export_type == "folder" and path or vim.fn.fnamemodify(path, ":p:h")) .. "/" .. file

  if Fs.write_json(file, collection, { escape = true }) then Logger.info("Exported collection: " .. file) end

  return collection
end

return M
