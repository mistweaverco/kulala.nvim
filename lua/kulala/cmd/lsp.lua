local Config = require("kulala.config")
local Db = require("kulala.db")
local Diagnostics = require("kulala.cmd.diagnostics")
local Dynamic_variables = require("kulala.parser.dynamic_vars")
local Env = require("kulala.parser.env")
local Export = require("kulala.cmd.export")
local Fmt = require("kulala.formatter.fmt")
local Formatter = require("kulala.formatter.formatter")
local Fs = require("kulala.utils.fs")
local Globals = require("kulala.globals")
local Inspect = require("kulala.parser.inspect")
local Kulala = require("kulala")
local Logger = require("kulala.logger")
local Lsp_sources = require("kulala.cmd.lsp_sources")
local Oauth = require("kulala.ui.auth_manager")
local Parser = require("kulala.parser.document")
local Ui = require("kulala.ui")
local VarParser = require("kulala.parser.string_variables_parser")

local M = {}

local lsp_kind = vim.lsp.protocol.CompletionItemKind
local lsp_format = vim.lsp.protocol.InsertTextFormat

local trigger_chars = { "@", "#", "-", ":", "{", "$", ">", "<", ".", "(", '"' }

local function make_item(label, description, kind, detail, documentation, text, format, score)
  return {
    label = label or "",
    labelDetails = {
      description = description or "",
    },
    kind = kind or "",
    detail = detail or "",
    documentation = {
      value = documentation or "",
      kind = vim.lsp.protocol.MarkupKind.Markdown,
    },
    insertText = text or "",
    insertTextFormat = format or lsp_format.PlainText,
    sortText = score or tostring(1.02), -- fix for blink.cmp
  }
end

---@param source Source
local function generic_source(source)
  local src_tbl, description, global, kind, format, score = unpack(source)
  kind = kind or lsp_kind.Value

  local items = {}

  local label, text, documentation
  vim.iter(src_tbl):each(function(item)
    label, text, documentation = item[1], item[2] or item[1], item[3]
    table.insert(items, make_item(label, description, kind, text, documentation, text, format, score))

    if global then
      label = label:gsub("^([^%-]+)", "%1-global")
      table.insert(
        items,
        table.insert(items, make_item(label, description, kind, text, documentation, text, format, score))
      )
    end
  end)

  return items
end

local state = {
  current_buffer = 0,
  current_line = 0, -- 1-based line number
  current_ft = nil,
}

local cache = {
  buffer = nil,
  lnum = nil,
  requests = nil,
  document_variables = nil,
  dynamic_variables = nil,
  env_variables = nil,
  auth_configs = nil,
  scripts = nil,
  symbols = nil,
  graphql = {},
  is_fresh = function(self)
    return self.buffer == state.current_buffer and self.lnum == state.current_line
  end,
  update = function(self)
    self.buffer = state.current_buffer
    self.lnum = state.current_line
  end,
}

local function get_document()
  if cache:is_fresh() and cache.document_variables and cache.requests then return end

  Db.set_current_buffer(state.current_buffer)
  cache.requests = Parser.get_document()
  cache.document_variables = vim.iter(cache.requests):fold({}, function(acc, request)
    return vim.tbl_extend("force", acc, request.variables)
  end)

  cache:update()
end

local url_len = 30

local function request_names()
  local kind = lsp_kind.Value
  local items = {}

  get_document()

  vim.iter(cache.requests):each(function(request)
    local file = vim.fs.basename(request.file)
    local short_name = request.name:sub(1, url_len)
    table.insert(items, make_item(short_name, file, kind, request.name, request.body, request.name))
  end)

  return items
end

local function request_urls()
  local kind = lsp_kind.Value
  local unique, items = {}, {}

  get_document()

  vim.iter(cache.requests):each(function(request)
    local url = request.url:gsub("^https?://", "")

    if not vim.tbl_contains(unique, url) then
      table.insert(unique, url)
      table.insert(items, make_item(url:sub(1, url_len), "", kind, url, "", url))
    end
  end)

  return items
end

local function document_variables()
  local kind = lsp_kind.Variable
  local items = {}

  get_document()

  vim.iter(cache.document_variables):each(function(name, value)
    table.insert(items, make_item(name, "Document var", kind, name, value, name))
  end)

  return items
end

local function dynamic_variables()
  local kind = lsp_kind.Variable
  local items = {}

  local auth_vars = {
    ["$auth.token"] = "Oauth2 Access Token",
    ["$auth.idToken"] = "Oauth2 Id Token",
  }

  cache.dynamic_variables = cache.dynamic_variables or Dynamic_variables.retrieve_all()

  vim.iter(cache.dynamic_variables):each(function(name, value)
    value = type(value) == "function" and tostring(value()) or value
    table.insert(items, make_item(name, "Dynamic var", lsp_kind.Variable, name, value, name))
  end)

  kind = lsp_kind.Snippet
  local format = lsp_format.Snippet

  vim.iter(auth_vars):each(function(name, value)
    table.insert(items, make_item(name, "Dynamic var", kind, name, value, "\\" .. name .. '("$1")$0', format))
  end)

  return items
end

local function env_variables()
  local kind = lsp_kind.Variable
  local items = {}

  if not cache:is_fresh() or not cache.env_variables then
    cache.env_variables = Env.get_env() or {}
    cache:update()
  end

  vim.iter(cache.env_variables):each(function(name, value)
    table.insert(items, make_item(name, "Env var", kind, name, value, name))
  end)

  return items
end

local function auth_configs()
  local kind = lsp_kind.Variable
  local items = {}

  cache.auth_configs = cache.auth_configs or Oauth.get_env()

  vim.iter(vim.tbl_keys(cache.auth_configs)):each(function(name)
    local config = vim.inspect(cache.auth_configs[name]):sub(1, 300)
    table.insert(items, make_item(name, "Auth Config", kind, name, config, name))
  end)

  return items
end

local function scripts()
  if cache.scripts then return cache.scripts end

  cache.scripts = {}

  vim.list_extend(cache.scripts, Lsp_sources.script_client)
  vim.list_extend(cache.scripts, Lsp_sources.script_request)
  vim.list_extend(cache.scripts, Lsp_sources.script_response)
  vim.list_extend(cache.scripts, Lsp_sources.script_assert)

  return cache.scripts
end

local function find_upwards(cur_line, pattern)
  for i = cur_line - 1, 0, -1 do
    local line = vim.api.nvim_buf_get_lines(state.current_buffer, i, i + 1, false)[1] or ""
    local match = line:match(pattern)

    if match then return match, i end
    if line:match("###") then break end
  end
end

local function get_graphql_type(req_name, field_name, type)
  local description = "`kind:` [" .. type.kind .. "]"

  description = type.name and (description .. ", `name:` [" .. type.name .. "]") or description
  description = type.ofType and (description .. " (" .. get_graphql_type(req_name, field_name, type.ofType) .. ")")
    or description

  if type.kind == "OBJECT" then cache.graphql[req_name].field_types[field_name] = type.name end

  return description
end

local function get_graphql_args(req_name, field_name, args)
  local kind = lsp_kind.Variable

  return vim
    .iter(args or {})
    :map(function(arg)
      local type = get_graphql_type(req_name, field_name, arg.type)
      local details = "`name`: [" .. arg.name .. "]\n" .. "`type`: " .. type .. "\n"

      details = arg.defaultValue and (details .. "`defaultValue`: " .. arg.defaultValue .. "\n") or details

      return make_item(arg.name, "GQL:arg", kind, arg.name, details, arg.name)
    end)
    :totable()
end

local function get_graphql_fields(req_name, fields)
  local kind = lsp_kind.Variable

  return vim
    .iter(fields or {})
    :map(function(field)
      local details = { "`type`: " .. get_graphql_type(req_name, field.name, field.type) }
      local args = get_graphql_args(req_name, field.name, field.args)

      _ = #args > 0
        and table.insert(details, "\n**args**:\n" .. vim
          .iter(args)
          :fold("", function(acc, item)
            return acc .. item.documentation.value .. "\n"
          end)
          :gsub("\n$", ""))

      local item = make_item(field.name, "GQL:field", kind, field.name, table.concat(details, "\n"), field.name)
      item.args = args

      return item
    end)
    :totable()
end

local function get_graphql_types(req_name, types)
  local kind = lsp_kind.Variable

  return vim
    .iter(types)
    :map(function(type)
      local fields = get_graphql_fields(req_name, type.fields)
      local details = {}

      table.insert(details, "**kind**: " .. type.kind)
      _ = type.description and table.insert(details, "**description:** " .. type.description)

      _ = #fields > 0
        and table.insert(details, "\n**fields:**\n\n" .. vim.iter(fields):fold("", function(acc, item)
          return acc .. item.documentation.value .. "\n"
        end))

      local item = make_item(type.name, "GQL:type", kind, type.name, table.concat(details, "\n"), type.name)
      item.fields = fields

      return item
    end)
    :totable()
end

local function graphql()
  get_document()

  vim.treesitter.get_parser(state.current_buffer):parse()

  local node = vim.treesitter.get_node()
  if node and node:type() == "json_body" then return {} end

  local request = vim.iter(cache.requests or {}):find(function(r)
    return state.current_line >= r.start_line - 1 and state.current_line <= r.end_line - 1
  end)

  if not request then return {} end

  local schema_name = request.url
  if schema_name:find("{{") then
    env_variables()
    schema_name = VarParser.parse(schema_name, cache.document_variables or {}, cache.env_variables or {})
  end

  schema_name = schema_name:gsub("https?://", ""):match("([^/]+)")

  if not cache.graphql[schema_name] or cache.graphql[schema_name] == "no_schema" then
    local schema_path = Fs.get_current_buffer_dir() .. "/" .. schema_name .. ".graphql-schema.json"
    local schema = Fs.read_json(schema_path)

    if not schema then
      -- show warining only once
      _ = not cache.graphql[schema_name]
        and Logger.warn("Cannot find " .. schema_path .. ". LSP GraphQL features will not be available.")
      cache.graphql[schema_name] = "no_schema"
      return {}
    end

    cache.graphql[schema_name] = { queryType = schema.data.__schema.queryType.name, types = {}, field_types = {} }
    cache.graphql[schema_name].types = get_graphql_types(schema_name, schema.data.__schema.types)
  end

  local lnum, cnum = state.current_line - 1, vim.fn.col(".") - 1
  local is_args = vim.api.nvim_buf_get_text(state.current_buffer, lnum, 0, lnum, cnum, {})[1]:match("%s*(.+)%s*%(")

  local parent = find_upwards(lnum, "%s*([^%s%(]+).*{")
  parent = parent == "query" and cache.graphql[schema_name].queryType
    or cache.graphql[schema_name].field_types[parent]
    or parent

  local parent_type = vim.iter(cache.graphql[schema_name].types):find(function(item)
    return item.label:lower() == parent:lower()
  end)

  if not parent_type or not parent_type.fields then return cache.graphql[schema_name].types end

  if is_args then
    local field = vim.iter(parent_type.fields):find(function(item)
      return item.label:lower() == is_args:lower()
    end)
    return field and field.args or {}
  end

  return parent_type.fields
end

---@class Source
---@field [1] SourceTable The source table
---@field [2] string The source name
---@field [3] boolean|nil Whether the source has global options
---@field [4] integer|nil The source kind lsp_kind
---@field [5] integer|nil The source insert text format lsp_format

---@type table<string, Source|function>
local sources = {
  request_names = request_names,
  request_urls = request_urls,
  document_variables = document_variables,
  dynamic_variables = dynamic_variables,
  env_variables = env_variables,
  auth_configs = auth_configs,
  methods = { Lsp_sources.methods, "Method" },
  schemes = { Lsp_sources.schemes, "Scheme" },
  header_names = { Lsp_sources.header_names, "Header name" },
  header_values = { Lsp_sources.header_values, "Header value" },
  metadata = { Lsp_sources.metadata, "Metadata" },
  curl = { Lsp_sources.curl, "Curl" },
  grpc = { Lsp_sources.grpc, "Grpc" },
  commands = { Lsp_sources.commands, "Command" },
  scripts = { scripts(), "API", false, lsp_kind.Snippet, lsp_format.Snippet },
  snippets_in = { Lsp_sources.snippets_in, "Snippets", false, lsp_kind.Snippet, lsp_format.Snippet },
  snippets_out = { Lsp_sources.snippets_out, "Snippets", false, lsp_kind.Snippet, lsp_format.Snippet },
  graphql = graphql,
}

local function source_type(params)
  local line =
    vim.api.nvim_buf_get_lines(state.current_buffer, params.position.line, params.position.line + 1, false)[1]

  line = line and line:sub(1, params.position.character) or ""

  local matches = {
    { "@curl%-", "curl" },
    { "@grpc%-", "grpc" },
    { "^run #", "request_names" },
    { '%$auth%.%w+oken%("[^"]+$', "auth_configs" },
    { "{{%$", "dynamic_variables" },
    { "{{", { "document_variables", "env_variables", "request_names" } },
    { "{%%", "scripts" },
    { "/", "request_urls" },
    { "Host:", "request_urls" },
    { ".:[^/]*", "header_values" },
    { "# @", "metadata" },
    { "[A-Z]+ ", { "schemes", "request_urls" } },
    { "<", "snippets_in" },
    { ">", "snippets_out" },
  }

  if state.current_ft == "javascript" then return { "scripts" } end

  for _, match in ipairs(matches) do
    if line:match(match[1]) then return match[2] end
  end

  if find_upwards(params.position.line, "query.*{") or find_upwards(params.position.line, "mutation.*{") then
    return { "graphql", "urls" }
  end

  if find_upwards(params.position.line, "{%%") then return { "scripts", "urls", "header_names", "header_values" } end

  return { "commands", "methods", "schemes", "urls", "header_names", "snippets" }
end

local get_source = function(params)
  local buf = vim.uri_to_bufnr(params.textDocument.uri)
  local source_name = source_type(params)
  source_name = type(source_name) == "table" and source_name or { source_name }

  local items
  local results = {
    isIncomplete = false,
    items = {},
  }

  vim.iter(sources):each(function(name, source)
    if vim.tbl_contains(source_name, name) then
      items = type(source) == "function" and source(buf) or generic_source(source)
      vim.list_extend(results.items, items)
    end
  end)

  return results
end

local function code_actions_fmt()
  return { { group = "Formatting", title = "Convert to HTTP", command = "convert_http", fn = Fmt.convert } }
end

local function code_actions_http()
  return {
    { group = "cURL", title = "Copy as cURL", command = "copy_as_curl", fn = Kulala.copy },
    {
      group = "cURL",
      title = "Paste from curl",
      command = "paste_from_curl",
      fn = Kulala.from_curl,
    },
    { group = "Request", title = "Inspect current request", command = "inspect_current_request", fn = Kulala.inspect },
    { group = "Request", title = "Open Cookies Jar", command = "open_cookie_jar", fn = Kulala.open_cookies_jar },
    {
      group = "Environment",
      title = "Select environment",
      command = "select_environment",
      fn = function()
        Kulala.set_selected_env()
      end,
    },
    {
      group = "Authentication",
      title = "Manage Auth Config",
      command = "manage_auth_config",
      fn = require("kulala.ui.auth_manager").open_auth_config,
    },
    { group = "Request", title = "Replay last request", command = "replay_last request", fn = Kulala.replay },
    {
      group = "GraphQL",
      title = "Download GraphQL schema",
      command = "download_graphql_schema",
      fn = Kulala.download_graphql_schema,
    },
    {
      group = "Environment",
      title = "Clear globals",
      command = "clear_globals",
      fn = function()
        Kulala.scripts_clear_global()
      end,
    },
    {
      group = "Environment",
      title = "Clear cached files",
      command = "clear_cached_files",
      fn = Kulala.clear_cached_files,
    },
    { group = "Request", title = "Send request", command = "run_request", fn = Ui.open },
    {
      group = "Request",
      title = "Send all requests",
      command = "run_request_all",
      fn = function()
        Ui.open_all()
      end,
    },
    {
      group = "Request",
      title = "Export file",
      command = "export_file",
      fn = Export.export_requests,
    },
    {
      group = "Request",
      title = "Export folder",
      command = "export_folder",
      fn = Export.export_requests,
    },
  }
end

local function code_actions()
  return (state.current_ft == "http" or state.current_ft == "rest") and code_actions_http() or code_actions_fmt()
end

local function get_symbol(name, kind, lnum, cnum)
  if not name or vim.trim(name) == "" then return end

  lnum = lnum or 0
  cnum = cnum or 0

  return {
    name = name,
    kind = kind,
    range = {
      start = { line = lnum, character = cnum },
      ["end"] = { line = lnum + 1, character = cnum },
    },
    selectionRange = {
      start = { line = lnum, character = cnum },
      ["end"] = { line = lnum + 1, character = cnum },
    },
    children = {},
  }
end

local function compact(str)
  return str:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""):gsub('([{:,"])%s', "%1"):gsub("\n", "")
end

local function get_symbols()
  local kind = vim.lsp.protocol.SymbolKind
  local symbols, symbol = {}, {}

  if cache:is_fresh() and cache.symbols then return cache.symbols end

  get_document()

  vim.iter(cache.requests):each(function(request)
    local cnum = 0
    local line = request.show_icon_line_number - 2

    symbol = get_symbol(request.name, kind.Function, line)
    if not symbol then return end

    if #request.scripts.pre_request.inline + #request.scripts.pre_request.files > 0 then
      table.insert(symbol.children, get_symbol("|< Pre-request script", kind.Module, line - 2))
    end

    vim.iter(request.metadata):each(function(meta)
      cnum = cnum + 1
      local metadata = meta.name .. (meta.value and " " .. meta.value or "")
      table.insert(symbol.children, get_symbol(metadata, kind.TypeParameter, line - 1, cnum))
    end)

    vim.list_extend(symbol.children, {
      get_symbol(request.method, kind.Object, line, 1),
      get_symbol(request.url, kind.Object, line, 2),
      get_symbol(request.host, kind.Key, line, 3),
    })

    cnum = 0
    vim.iter(request.headers):each(function(k, v)
      table.insert(symbol.children, get_symbol(k .. ":" .. v, kind.Boolean, line + 1, cnum))
      cnum = cnum + 1
    end)

    vim.list_extend(symbol.children, { get_symbol(compact(request.body), kind.String, line + 2) })

    if #request.scripts.post_request.inline + #request.scripts.post_request.files > 0 then
      table.insert(symbol.children, get_symbol("|< Post-request script", kind.Module, line + 3))
    end

    table.insert(symbols, symbol)
  end)

  cache.symbols = symbols
  cache:update()

  return symbols
end

local function get_hover(_)
  return { contents = { language = "http", value = table.concat(Inspect.get_contents(), "\n") } }
end

local function format(params)
  if not Config.options.lsp.formatter then return end

  local formatted_lines = Formatter.format(state.current_buffer, params)
  return formatted_lines or {}
end

M.foldtext = function()
  vim.api.nvim_set_option_value(
    "foldtext",
    "v:lua.require'kulala.cmd.lsp'.foldtext()",
    { win = vim.api.nvim_get_current_win() }
  )

  local line = vim.fn.getline(vim.v.foldstart)
  return "▶ " .. line .. " [" .. (vim.v.foldend - vim.v.foldstart + 1) .. " lines]"
end

local function folding()
  if not vim.api.nvim_buf_is_loaded(state.current_buffer) then return {} end

  local tree = vim.treesitter.get_parser(state.current_buffer, "kulala_http"):parse()[1]
  local root = tree:root()

  local ranges = {}

  local function traverse(node)
    for child in node:iter_children() do
      local start_row, _, end_row, _ = child:range()

      local type = child:type()
      local kind = type == "comment" and type or "region"

      if type == "request_separator" then
        start_row = start_row + 1
        end_row = select(3, child:parent():range())
      end

      if end_row > start_row and child:type() ~= "section" then
        table.insert(ranges, {
          startLine = start_row,
          endLine = end_row - 1,
          kind = kind,
          type = child:type(),
        })
      end

      traverse(child)
    end
  end

  traverse(root)

  return ranges
end

local function initialize(params)
  local ft = params.rootPath:sub(2)
  local capabilities

  if ft == "javascript" then
    capabilities = { completionProvider = { triggerCharacters = trigger_chars } }
  elseif ft ~= "http" and ft ~= "rest" then
    capabilities = { codeActionProvider = true }
  else
    capabilities = {
      codeActionProvider = true,
      documentSymbolProvider = true,
      hoverProvider = true,
      completionProvider = { triggerCharacters = trigger_chars },
      documentFormattingProvider = true,
      documentRangeFormattingProvider = true,
      foldingRangeProvider = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      },
    }
  end

  return {
    serverInfo = { name = "Kulala LSP", version = Globals.VERSION },
    capabilities = capabilities,
  }
end

local handlers = {
  ["initialize"] = initialize,
  ["textDocument/completion"] = get_source,
  ["textDocument/documentSymbol"] = get_symbols,
  ["textDocument/hover"] = get_hover,
  ["textDocument/codeAction"] = code_actions,
  ["textDocument/formatting"] = format,
  ["textDocument/rangeFormatting"] = format,
  ["textDocument/foldingRange"] = folding,
  ["shutdown"] = function() end,
}

local function set_current_buf(params)
  if not (params and params.textDocument and params.textDocument.uri) then return end

  local buf = vim.uri_to_bufnr(params.textDocument.uri)
  local buf_valid = vim.api.nvim_buf_is_valid(buf)

  state.current_buffer = buf_valid and buf or 0
  state.current_ft = buf_valid and vim.api.nvim_get_option_value("filetype", { buf = buf }) or nil

  local win = buf_valid and vim.fn.win_findbuf(buf)[1] or 0
  state.current_line = vim.api.nvim_win_get_cursor(win)[1]
end

local function new_server()
  local function server(dispatchers)
    local closing = false
    local srv = {}

    function srv.request(method, params, handler)
      local status, error = xpcall(function()
        set_current_buf(params)
        _ = handlers[method] and handler(nil, handlers[method](params))
      end, debug.traceback)

      if not status then
        require("kulala.logger").error("Errors in Kulala LSP:\n" .. (error or ""), 2, { report = true })
      end

      return true
    end

    function srv.notify(method, _)
      if method == "exit" then dispatchers.on_exit(0, 15) end
    end

    function srv.is_closing()
      return closing
    end

    function srv.terminate()
      closing = true
    end

    return srv
  end

  return server
end

M.start = function(buf, ft)
  M.start_lsp(buf, ft)

  _ = (ft == "http" or ft == "rest")
    and vim.iter(trigger_chars):each(function(char)
      pcall(function()
        vim.keymap.del("i", char, { buffer = buf }) -- remove autopairs mappings
      end)
    end)
end

function M.start_lsp(buf, ft)
  local server = new_server()

  local dispatchers = {
    on_exit = function(code, signal)
      Logger.error("Server exited with code " .. code .. " and signal " .. signal)
    end,
  }

  local actions = vim.list_extend(code_actions_http(), code_actions_fmt())

  local client_id = vim.lsp.start({
    name = "kulala",
    cmd = server,
    root_dir = ft,
    bufnr = buf,
    on_attach = function(client, bufnr)
      _ = (ft == "http" or ft == "rest") and Diagnostics.setup(bufnr)
      _ = Config.options.lsp.on_attach and Config.options.lsp.on_attach(client, bufnr)
    end,
    commands = vim.iter(actions):fold({}, function(acc, action)
      acc[action.command] = action.fn
      return acc
    end),
  }, dispatchers)

  return client_id
end

return M
