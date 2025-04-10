local Dynamic_variables = require("kulala.parser.dynamic_vars")
local Env = require("kulala.parser.env")
local Inspect = require("kulala.parser.inspect")
local Kulala = require("kulala")
local Oauth = require("kulala.ui.auth_manager")
local Ui = require("kulala.ui")

local Parser = require("kulala.parser.document")

local M = {}

local lsp_kind = vim.lsp.protocol.CompletionItemKind
local lsp_format = vim.lsp.protocol.InsertTextFormat

local trigger_chars = { "@", "#", "-", ":", "{", "$", ">", "<", ".", "(", '"' }

---@alias SourceTable SourceItem[]
---@class SourceItem
---@field [1] string Label
---@field [2] string|nil InsertText
---@field [3] string|nil Documentation

---@type SourceTable
local snippets = {
  { ">>", "> ", "Redirect output to file" },
  { ">>!", ">! ", "Redirect output to file ovewriting" },
  { "< {% %}", " {%\n\t${0}\n%}\n", "Pre-request script" },
  { "> {% %}", " {%\n\t${0}\n%}\n", "Post-request script" },
  { "< {% %}", " {%\n\t-- lua\n${0}\n%}\n", "Pre-request lua script" },
  { "> {% %}", " {%\n\t-- lua\n${0}\n%}\n", "Post-request lua script" },
}

---@type SourceTable
local commands = {
  { "run #", "run #", "Run request #name" },
  { "run ../", "run ", "Run requests in file" },
  { "import", "import ", "Import requests" },
}

---@type SourceTable
local methods = {
  { "GET", "GET " },
  { "POST", "POST " },
  { "PUT", "PUT " },
  { "DELETE", "DELETE " },
  { "PATCH", "PATCH " },
  { "HEAD", "HEAD " },
  { "OPTIONS", "OPTIONS " },
  { "TRACE", "TRACE " },
  { "CONNECT", "CONNECT " },
  { "GRAPHQL", "GRAPHQL " },
  { "GRPC", "GRPC " },
  { "WS", "WS " },
}

---@type SourceTable
local schemes = {
  { "http", "http://" },
  { "https", "https://" },
  { "ws", "ws://" },
  { "wss", "wss://" },
}

---@type SourceTable
local header_names = {
  { "A-IM", "A-IM " },
  { "Accept", "Accept " },
  { "Accept-Additions", "Accept-Additions " },
  { "Accept-CH", "Accept-CH " },
  { "Accept-Datetime", "Accept-Datetime " },
  { "Accept-Encoding", "Accept-Encoding " },
  { "Accept-Features", "Accept-Features " },
  { "Accept-Language", "Accept-Language " },
  { "Accept-Patch", "Accept-Patch " },
  { "Accept-Post", "Accept-Post " },
  { "Accept-Ranges", "Accept-Ranges " },
  { "Accept-Signature", "Accept-Signature " },
  { "Access-Control-Allow-Credentials", "Access-Control-Allow-Credentials " },
  { "Access-Control-Allow-Headers", "Access-Control-Allow-Headers " },
  { "Access-Control-Allow-Methods", "Access-Control-Allow-Methods " },
  { "Access-Control-Allow-Origin", "Access-Control-Allow-Origin " },
  { "Access-Control-Expose-Headers", "Access-Control-Expose-Headers " },
  { "Access-Control-Max-Age", "Access-Control-Max-Age " },
  { "Access-Control-Request-Headers", "Access-Control-Request-Headers " },
  { "Access-Control-Request-Method", "Access-Control-Request-Method " },
  { "Age", "Age " },
  { "Allow", "Allow " },
  { "ALPN", "ALPN " },
  { "Alt-Svc", "Alt-Svc " },
  { "Alt-Used", "Alt-Used " },
  { "Alternates", "Alternates " },
  { "Apply-To-Redirect-Ref", "Apply-To-Redirect-Ref " },
  { "Authentication-Control", "Authentication-Control " },
  { "Authentication-Info", "Authentication-Info " },
  { "Authorization", "Authorization " },
  { "Available-Dictionary", "Available-Dictionary " },
  { "Cache-Control", "Cache-Control " },
  { "Cache-Status", "Cache-Status " },
  { "Cal-Managed-ID", "Cal-Managed-ID " },
  { "CalDAV-Timezones", "CalDAV-Timezones " },
  { "Capsule-Protocol", "Capsule-Protocol " },
  { "CDN-Cache-Control", "CDN-Cache-Control " },
  { "CDN-Loop", "CDN-Loop " },
  { "Cert-Not-After", "Cert-Not-After " },
  { "Cert-Not-Before", "Cert-Not-Before " },
  { "Clear-Site-Data", "Clear-Site-Data " },
  { "Client-Cert", "Client-Cert " },
  { "Client-Cert-Chain", "Client-Cert-Chain " },
  { "Close", "Close " },
  { "Concealed-Auth-Export", "Concealed-Auth-Export " },
  { "Connection", "Connection " },
  { "Content-Digest", "Content-Digest " },
  { "Content-Disposition", "Content-Disposition " },
  { "Content-Encoding", "Content-Encoding " },
  { "Content-Language", "Content-Language " },
  { "Content-Length", "Content-Length " },
  { "Content-Location", "Content-Location " },
  { "Content-Range", "Content-Range " },
  { "Content-Security-Policy", "Content-Security-Policy " },
  { "Content-Security-Policy-Report-Only", "Content-Security-Policy-Report-Only " },
  { "Content-Type", "Content-Type " },
  { "Cookie", "Cookie " },
  { "Cross-Origin-Embedder-Policy", "Cross-Origin-Embedder-Policy " },
  { "Cross-Origin-Embedder-Policy-Report-Only", "Cross-Origin-Embedder-Policy-Report-Only " },
  { "Cross-Origin-Opener-Policy", "Cross-Origin-Opener-Policy " },
  { "Cross-Origin-Opener-Policy-Report-Only", "Cross-Origin-Opener-Policy-Report-Only " },
  { "Cross-Origin-Resource-Policy", "Cross-Origin-Resource-Policy " },
  { "DASL", "DASL " },
  { "Date", "Date " },
  { "DAV", "DAV " },
  { "Delta-Base", "Delta-Base " },
  { "Deprecation", "Deprecation " },
  { "Depth", "Depth " },
  { "Destination", "Destination " },
  { "Detached-JWS", "Detached-JWS " },
  { "Dictionary-ID", "Dictionary-ID " },
  { "DPoP", "DPoP " },
  { "DPoP-Nonce", "DPoP-Nonce " },
  { "Early-Data", "Early-Data " },
  { "ETag", "ETag " },
  { "Expect", "Expect " },
  { "Expires", "Expires " },
  { "Forwarded", "Forwarded " },
  { "From", "From " },
  { "Hobareg", "Hobareg " },
  { "Host", "Host " },
  { "If", "If " },
  { "If-Match", "If-Match " },
  { "If-Modified-Since", "If-Modified-Since " },
  { "If-None-Match", "If-None-Match " },
  { "If-Range", "If-Range " },
  { "If-Schedule-Tag-Match", "If-Schedule-Tag-Match " },
  { "If-Unmodified-Since", "If-Unmodified-Since " },
  { "IM", "IM " },
  { "Include-Referred-Token-Binding-ID", "Include-Referred-Token-Binding-ID " },
  { "Keep-Alive", "Keep-Alive " },
  { "Label", "Label " },
  { "Last-Event-ID", "Last-Event-ID " },
  { "Last-Modified", "Last-Modified " },
  { "Link", "Link " },
  { "Link-Template", "Link-Template " },
  { "Location", "Location " },
  { "Lock-Token", "Lock-Token " },
  { "Max-Forwards", "Max-Forwards " },
  { "Memento-Datetime", "Memento-Datetime " },
  { "Meter", "Meter " },
  { "MIME-Version", "MIME-Version " },
  { "Negotiate", "Negotiate " },
  { "NEL", "NEL " },
  { "OData-EntityId", "OData-EntityId " },
  { "OData-Isolation", "OData-Isolation " },
  { "OData-MaxVersion", "OData-MaxVersion " },
  { "OData-Version", "OData-Version " },
  { "Optional-WWW-Authenticate", "Optional-WWW-Authenticate " },
  { "Ordering-Type", "Ordering-Type " },
  { "Origin", "Origin " },
  { "Origin-Agent-Cluster", "Origin-Agent-Cluster " },
  { "OSCORE", "OSCORE " },
  { "OSLC-Core-Version", "OSLC-Core-Version " },
  { "Overwrite", "Overwrite " },
  { "Ping-From", "Ping-From " },
  { "Ping-To", "Ping-To " },
  { "Position", "Position " },
  { "Prefer", "Prefer " },
  { "Preference-Applied", "Preference-Applied " },
  { "Priority", "Priority " },
  { "Proxy-Authenticate", "Proxy-Authenticate " },
  { "Proxy-Authentication-Info", "Proxy-Authentication-Info " },
  { "Proxy-Authorization", "Proxy-Authorization " },
  { "Proxy-Status", "Proxy-Status " },
  { "Public-Key-Pins", "Public-Key-Pins " },
  { "Public-Key-Pins-Report-Only", "Public-Key-Pins-Report-Only " },
  { "Range", "Range " },
  { "Redirect-Ref", "Redirect-Ref " },
  { "Referer", "Referer " },
  { "Referrer-Policy", "Referrer-Policy " },
  { "Refresh", "Refresh " },
  { "Replay-Nonce", "Replay-Nonce " },
  { "Repr-Digest", "Repr-Digest " },
  { "Retry-After", "Retry-After " },
  { "Schedule-Reply", "Schedule-Reply " },
  { "Schedule-Tag", "Schedule-Tag " },
  { "Sec-Fetch-Dest", "Sec-Fetch-Dest " },
  { "Sec-Fetch-Mode", "Sec-Fetch-Mode " },
  { "Sec-Fetch-Site", "Sec-Fetch-Site " },
  { "Sec-Fetch-User", "Sec-Fetch-User " },
  { "Sec-Purpose", "Sec-Purpose " },
  { "Sec-Token-Binding", "Sec-Token-Binding " },
  { "Sec-WebSocket-Accept", "Sec-WebSocket-Accept " },
  { "Sec-WebSocket-Extensions", "Sec-WebSocket-Extensions " },
  { "Sec-WebSocket-Key", "Sec-WebSocket-Key " },
  { "Sec-WebSocket-Protocol", "Sec-WebSocket-Protocol " },
  { "Sec-WebSocket-Version", "Sec-WebSocket-Version " },
  { "Server", "Server " },
  { "Server-Timing", "Server-Timing " },
  { "Set-Cookie", "Set-Cookie " },
  { "Signature", "Signature " },
  { "Signature-Input", "Signature-Input " },
  { "SLUG", "SLUG " },
  { "SoapAction", "SoapAction " },
  { "Status-URI", "Status-URI " },
  { "Strict-Transport-Security", "Strict-Transport-Security " },
  { "Sunset", "Sunset " },
  { "TCN", "TCN " },
  { "TE", "TE " },
  { "Timeout", "Timeout " },
  { "Topic", "Topic " },
  { "Traceparent", "Traceparent " },
  { "Tracestate", "Tracestate " },
  { "Trailer", "Trailer " },
  { "Transfer-Encoding", "Transfer-Encoding " },
  { "TTL", "TTL " },
  { "Upgrade", "Upgrade " },
  { "Urgency", "Urgency " },
  { "Use-As-Dictionary", "Use-As-Dictionary " },
  { "User-Agent", "User-Agent " },
  { "Variant-Vary", "Variant-Vary " },
  { "Vary", "Vary " },
  { "Via", "Via " },
  { "Want-Content-Digest", "Want-Content-Digest " },
  { "Want-Repr-Digest", "Want-Repr-Digest " },
  { "WWW-Authenticate", "WWW-Authenticate " },
  { "X-Content-Type-Options", "X-Content-Type-Options " },
  { "X-Frame-Options", "X-Frame-Options " },
  { "*", "* " },
  { "Activate-Storage-Access", "Activate-Storage-Access " },
  { "AMP-Cache-Transform", "AMP-Cache-Transform " },
  { "CMCD-Object", "CMCD-Object " },
  { "CMCD-Request", "CMCD-Request " },
  { "CMCD-Session", "CMCD-Session " },
  { "CMCD-Status", "CMCD-Status " },
  { "CMSD-Dynamic", "CMSD-Dynamic " },
  { "CMSD-Static", "CMSD-Static " },
  { "Configuration-Context", "Configuration-Context " },
  { "CTA-Common-Access-Token", "CTA-Common-Access-Token " },
  { "EDIINT-Features", "EDIINT-Features " },
  { "Isolation", "Isolation " },
  { "Permissions-Policy", "Permissions-Policy " },
  { "Repeatability-Client-ID", "Repeatability-Client-ID " },
  { "Repeatability-First-Sent", "Repeatability-First-Sent " },
  { "Repeatability-Request-ID", "Repeatability-Request-ID " },
  { "Repeatability-Result", "Repeatability-Result " },
  { "Reporting-Endpoints", "Reporting-Endpoints " },
  { "Sec-Fetch-Storage-Access", "Sec-Fetch-Storage-Access " },
  { "Sec-GPC", "Sec-GPC " },
  { "Surrogate-Capability", "Surrogate-Capability " },
  { "Surrogate-Control", "Surrogate-Control " },
  { "Timing-Allow-Origin", "Timing-Allow-Origin " },
}

---@type SourceTable
local header_values = {
  { "Bearer " },
  { "Basic " },
  { "Digest " },
  { "NTLM " },
  { "Negotiate" },
  { "AWS" },
  { "application/json" },
  { "application/xml" },
  { "application/x-www-form-urlencoded" },
  { "application/octet-stream" },
  { "application/pdf" },
  { "application/zip" },
  { "text/plain" },
  { "text/html" },
  { "text/css" },
  { "text/javascript" },
  { "text/xml" },
  { "image/jpeg" },
  { "image/png" },
  { "image/gif" },
  { "image/svg+xml" },
  { "image/webp" },
  { "audio/mpeg" },
  { "audio/wav" },
  { "audio/ogg" },
  { "video/mp4" },
  { "video/webm" },
  { "video/ogg" },
  { "multipart/form-data" },
  { "multipart/form-data; boundary=----WebKitFormBoundary{{$timestamp}}" },
  { "application/x-www-form-urlencoded" },
  { "chunked" },
  { "gzip" },
  { "deflate" },
  { "br" },
  { "identity" },
  { "compress" },
  { "x-gzip" },
  { "x-bzip2" },
  { "x-compress" },
  { "x-zip-compress" },
  { "x-zip" },
}

---@type SourceTable
local metadata = {
  { "name", "name", "Request name" },
  { "prompt", "prompt ", "Prompt" },
  { "curl", "curl", "Curl flag" },
  { "curl-global", "curl-global", "Curl global flag" },
  { "grpc", "grpc", "Grpc flag" },
  { "grpc-global", "Grpc-global", "Grpc global flag" },
  { "accept", "accept chunked", "Accept chunked responses" },
  { "env-stdin-cmd", "env-stdin-cmd ", "Set env variable with external cmd" },
  { "env-json-key", "env-json-kwy ", "Set env variable with json key" },
}

---@type SourceTable
local curl = {
  { "curl-compressed", "curl-compressed", "Decompress response" },
  { "curl-location", "curl-location", "Follow redirects" },
  { "curl-no-buffer", "curl-no-buffer", "Disable buffering" },
}

---@type SourceTable
local grpc = {
  { "grpc-import-path", "grpc-import-path", "Proto import path" },
  { "grpc-proto", "grpc-proto", "Proto file" },
  { "grpc-protoset", "grpc-protoset", "Protoset file" },
  { "grpc-plaintext", "grpc-plaintext", "No TLS" },
  { "grpc-v", "grpc-verbose", "Verbose" },
}

---@type SourceTable
local script_client = {
  { "client.global.get", "client.global.get(${1:varName})$0", "Get a  global variable" },
  { "client.global.set", "client.global.set(${1:varName}, ${2:value})$0", "Set a global variable" },
  { "client.log", "client.log(${1:message})$0", "Log message" },
  { "client.test", "client.test(${1:name}, ${2:fn})$0", "Define a test suite" },
  { "client.assert", "client.assert(${1:value}, ${2:message?})$0", "Checks if the value is truthy" },
  { "client.isEmpty", "client.isEmpty()$0", "Check if global variables are empty" },
  { "client.clear", "client.clear(${1:varName})$0", "Clear a global variable" },
  { "client.clearAll", "client.clearAll()$0", "Clear all global variables" },
  { "client.exit", "client.exit()$0", "Exit script" },
}

---@type SourceTable
local script_request = {
  { "request.variables.set", "request.variables.set(${1:varName}, ${2:value})$0", "Set a request variable" },
  { "request.variables.get", "request.variables.get(${1:varName})$0", "Get a request variable" },
  { "request.headers.all", "request.headers.all()$0", "Get all request headers" },
  { "name", "name()$0", "Get header name" },
  { "getRawValue", "getRawValue()$0", "Get raw request header value" },
  { "tryGetSubstituted", "tryGetSubstituted()$0", "Get substituted request header value" },
  { "request.headers.findByName", "request.headers.findByName(${1:name})$0", "Find request header by name" },
  { "request.body.getRaw", "request.body.getRaw()$0", "Get raw request body" },
  { "request.body.tryGetSubstituted", "request.body.tryGetSubstituted()$0", "Get substituted request body" },
  { "request.body.getComputed", "request.body.getComputed()$0", "Get computed request body" },
  { "request.environment.get", "request.environment.get(${1:varName})$0", "Get environment variable" },
  { "request.method", "request.method()$0", "Get request method" },
  { "request.url.getRaw", "request.url.getRaw()$0", "Get raw request URL" },
  { "request.url.tryGetSubstituted", "request.url.tryGetSubstituted()$0", "Get substituted request URL" },
  { "request.skip", "request.skip()$0", "Skip request" },
  { "request.replay", "request.replay()$0", "Replay request" },
}

---@type SourceTable
local script_response = {
  { "response.responseCode", "response.responseCode()$0", "Get response code" },
  { "response.body", "response.body()$0", "Get response body" },
  { "response.headers.all", "response.headers.all()$0", "Get all response headers" },
  { "valueOf", "valueOf()$0", "Get response header value" },
  { "valuesOf", "valuesOf()$0", "Get all response header values" },
}

---@type SourceTable
local script_assert = {

  { "assert", "assert(${1:value}, ${2:message?})$0", "Checks if the value is truthy" },
  { "assert.true", "assert.true(${1:value}, ${2:message?})$0", "Checks if the value is true" },
  { "assert.false", "assert.false(${1:value}, ${2:message?})$0", "Checks if the value is false" },
  {
    "assert.same",
    "assert.same(${1:value}, ${2:expected}, ${3:message?})$0",
    "Checks if the value is the same as the expected value",
  },
  {
    "assert.hasString",
    "assert.hasString(${1:value}, ${2:expected}, ${3:message?})$0",
    "Checks if the string contains the expected substring",
  },
  {
    "assert.responseHas",
    "assert.responseHas(${1:key}, ${2:expected}, ${3:message?})$0",
    "Checks if the response has the expected key with the expected value",
  },
  {
    "assert.headersHas",
    "assert.headersHas(${1:key}, ${2:expected}, ${3:message?})$0",
    "Checks if the response headers have the expected key with the expected value",
  },
  {
    "assert.bodyHas",
    "assert.bodyHas(${1:expected}, ${2:message?})$0",
    "Checks if the response body contains the expected string",
  },
  {
    "assert.jsonHas",
    "assert.jsonHas(${1:key}, ${2:expected}, ${3:message?})$0",
    "Checks if the JSON response has the expected key with the expected value",
  },
}

local function make_item(label, description, kind, detail, documentation, text, format, score)
  return {
    label = label,
    labelDetails = {
      description = description,
    },
    kind = kind,
    detail = detail,
    documentation = {
      value = documentation,
      kind = vim.lsp.protocol.MarkupKind.Markdown,
    },
    insertText = text,
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
  is_fresh = function(self)
    return self.buffer == vim.fn.bufnr() and self.lnum == vim.fn.line(".")
  end,
  update = function(self)
    self.buffer = vim.fn.bufnr()
    self.lnum = vim.fn.line(".")
  end,
}

local function get_document()
  if cache:is_fresh() and cache.document_variables and cache.requests then return end
  cache.document_variables, cache.requests = Parser.get_document()
  cache:update()
end

local url_len = 30

local function request_names()
  local kind = lsp_kind.Value
  local items = {}

  get_document()

  vim.iter(cache.requests):each(function(request)
    local file = vim.fs.basename(request.file)
    local name = request.name:sub(1, url_len)
    table.insert(items, make_item(name, file, kind, name, request.body, name))
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
    table.insert(items, make_item(name, "Document var", kind, name, value, name .. "}}"))
  end)

  vim.iter(cache.requests):each(function(request)
    local req_metadata = request.metadata
    vim.iter(req_metadata):each(function(meta, value)
      _ = meta.name == "name"
        and table.insert(items, make_item(meta.value, "Request name", kind, meta.value, "", meta.value .. "}}"))
    end)
  end)

  return items
end

local function dynamic_variablies()
  local kind = lsp_kind.Variable
  local auth_vars = { ["$auth.token"] = "Auth", ["$auth.idToken"] = "Auth" }
  local items = {}

  cache.dynamic_variables = cache.dynamic_variables or Dynamic_variables.retrieve_all()

  vim.iter(cache.dynamic_variables):each(function(name, value)
    value = type(value) == "function" and tostring(value()) or value
    table.insert(items, make_item(name, value, lsp_kind.Variable, name, value, name:sub(2) .. "}}"))
  end)

  kind = lsp_kind.Snippet
  local format = lsp_format.Snippet

  vim.iter(auth_vars):each(function(name, value)
    table.insert(items, make_item(name, "Dynamic var", kind, name, value, name:sub(2) .. '("$1")}}$0', format))
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
    table.insert(items, make_item(name, "Env var", kind, name, value, name .. "}}"))
  end)

  return items
end

local function auth_configs()
  local kind = lsp_kind.Variable
  local items = {}

  cache.auth_configs = cache.auth_configs or Oauth.get_env()

  vim.iter(vim.tbl_keys(cache.auth_configs)):each(function(name)
    table.insert(items, make_item(name, "Auth", kind, name, "", name))
  end)

  return items
end

local function scripts()
  if cache.scripts then return cache.scripts end

  cache.scripts = {}

  vim.list_extend(cache.scripts, script_client)
  vim.list_extend(cache.scripts, script_request)
  vim.list_extend(cache.scripts, script_response)
  vim.list_extend(cache.scripts, script_assert)

  return cache.scripts
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
  dynamic_variables = dynamic_variablies,
  env_variables = env_variables,
  auth_configs = auth_configs,
  methods = { methods, "Method" },
  schemes = { schemes, "Scheme" },
  header_names = { header_names, "Header" },
  header_values = { header_values, "Header" },
  metadata = { metadata, "Metadata" },
  curl = { curl, "Curl" },
  grpc = { grpc, "Grpc" },
  commands = { commands, "Command" },
  scripts = { scripts(), "API", false, lsp_kind.Snippet, lsp_format.Snippet },
  snippets = { snippets, "Snippets", false, lsp_kind.Snippet, lsp_format.Snippet },
}

local function source_type(params)
  local line = vim.fn.getline(params.position.line + 1)
  line = line:sub(1, params.position.character)

  local matches = {
    { "@curl%-", "curl" },
    { "@curl%-global%-", "curl" },
    { "@grpc%-global%-", "grpc" },
    { "run #", "request_names" },
    { "auth(.+)oken%(", "auth_configs" },
    { "{{%$", "dynamic_variables" },
    { "{{", { "document_variables", "env_variables" } },
    { "{%%", "scripts" },
    { "/", "request_urls" },
    { "Host:", "request_urls" },
    { ".:[^/]*", "header_values" },
    { "# @", "metadata" },
    { "[A-Z]+ ", { "schemes", "request_urls" } },
    { "<", "snippets" },
    { ">", "snippets" },
  }

  for _, match in ipairs(matches) do
    if line:match(match[1]) then return match[2] end
  end

  local is_script = false
  for i = params.position.line, 1, -1 do
    if vim.fn.getline(i):match("###") then break end
    if vim.fn.getline(i):match("{%%") then
      is_script = true
      break
    end
  end

  if is_script then return { "scripts", "urls", "headers_names", "header_values" } end

  return { "commands", "methods", "schemes", "urls", "header_names", "snippets" }
end

local get_source = function(params)
  local source_name = source_type(params)
  source_name = type(source_name) == "table" and source_name or { source_name }

  local items
  local results = {
    isIncomplete = false,
    items = {},
  }

  vim.iter(sources):each(function(name, source)
    if vim.tbl_contains(source_name, name) then
      items = type(source) == "function" and source() or generic_source(source)
      vim.list_extend(results.items, items)
    end
  end)

  return results
end

local code_actions = {
  { title = "Copy as cURL", command = "copy_as_curl", fn = Kulala.copy },
  { title = "Paste from curl", command = "paste_from_curl", fn = Kulala.from_curl },
  { title = "Inspect current request", command = "inspect_current_request", fn = Kulala.inspect },
  {
    title = "Select environment",
    command = "select_environment",
    fn = function()
      Kulala.set_selected_env()
    end,
  },
  {
    title = "Manage Auth Config",
    command = "manage_auth_config",
    fn = require("kulala.ui.auth_manager").open_auth_config,
  },
  { title = "Replay last request", command = "replay_last request", fn = Kulala.replay },
  { title = "Download GraphQL schema", command = "download_graphql_schema", fn = Kulala.download_graphql_schema },
  {
    title = "Clear globals",
    command = "clear_globals",
    fn = function()
      Kulala.scripts_clear_global()
    end,
  },
  { title = "Clear cached files", command = "clear_cached_files", fn = Kulala.clear_cached_files },
  { title = "Send request", command = "run_request", fn = Ui.open },
  {
    title = "Send all requests",
    command = "run_request_all",
    fn = function()
      Ui.open_all()
    end,
  },
}

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

local function get_symbols(_)
  local kind = vim.lsp.protocol.SymbolKind
  local symbols, symbol = {}, {}

  if cache:is_fresh() and cache.symbols then return cache.symbols end

  get_document()

  vim.iter(cache.requests):each(function(request)
    local cnum = 0
    local line = request.show_icon_line_number - 2
    symbol = get_symbol(request.name, kind.Function, line) or {}

    if #request.scripts.pre_request.inline + #request.scripts.pre_request.files > 0 then
      table.insert(symbol.children, get_symbol("|< Pre-request script", kind.Module, line - 2))
    end

    vim.iter(request.metadata):each(function(meta)
      cnum = cnum + 1
      local meta = meta.name .. (meta.value and " " .. meta.value or "")
      table.insert(symbol.children, get_symbol(meta, kind.TypeParameter, line - 1, cnum))
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

  return symbols
end

local function get_hover(_)
  return { contents = { language = "http", value = table.concat(Inspect.get_contents(), "\n") } }
end

local function new_server()
  local function server(dispatchers)
    local closing = false
    local srv = {}

    function srv.request(method, params, handler)
      local status, error = xpcall(function()
        srv.request_p(method, params, handler)
      end, debug.traceback)

      if not status then require("kulala.logger").error("Errors in Kulala LSP:\n" .. (error or ""), 2) end
      return true
    end

    function srv.request_p(method, params, handler)
      if method == "initialize" then
        handler(nil, {
          capabilities = {
            codeActionProvider = true,
            documentSymbolProvider = true,
            hoverProvider = true,
            completionProvider = { triggerCharacters = trigger_chars },
          },
        })
      elseif method == "textDocument/completion" then
        handler(nil, get_source(params))
      elseif method == "textDocument/documentSymbol" then
        handler(nil, get_symbols(params))
      elseif method == "textDocument/hover" then
        handler(nil, get_hover(params))
      elseif method == "textDocument/codeAction" then
        handler(nil, code_actions)
      elseif method == "shutdown" then
        handler(nil, nil)
      end
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

M.start = function(buf)
  local root = vim.fs.dirname(vim.fn.bufname(buf))

  local client = vim.lsp.get_clients({ name = "kulala" })[1]
  if client then vim.lsp.stop_client(client.id) end

  vim.defer_fn(function()
    M.start_mock_lsp(root)
  end, client and 0 or 1000)

  vim.iter(trigger_chars):each(function(char)
    pcall(function()
      vim.keymap.del("i", char, { buffer = buf }) -- remove autopairs mappings
    end)
  end)
end

function M.start_mock_lsp(root_dir)
  local server = new_server()

  local dispatchers = {
    on_exit = function(code, signal)
      vim.notify("Server exited with code " .. code .. " and signal " .. signal, vim.log.levels.ERROR)
    end,
  }

  local client_id = vim.lsp.start({
    name = "kulala",
    cmd = server,
    root_dir = root_dir,
    on_init = function(_client) end,
    on_exit = function(_code, _signal) end,
    commands = vim.iter(code_actions):fold({}, function(acc, action)
      acc[action.command] = action.fn
      return acc
    end),
  }, dispatchers)
  return client_id
end

return M
