local M = {}

---@alias SourceTable SourceItem[]
---@class SourceItem
---@field [1] string Label
---@field [2] string|nil InsertText
---@field [3] string|nil Documentation

---@type SourceTable
M.snippets = {
  { ">>", "> ", "Redirect output to file" },
  { ">>!", ">! ", "Redirect output to file overwriting" },
  { "< {% %}", " {%\n\t${0}\n%}\n", "Pre-request script" },
  { "< ", " ${1:path/to/script.js}", "Pre-request script file" },
  { "> {% %}", " {%\n\t${0}\n%}\n", "Post-request script" },
  { "> ", " ${1:path/to/script.js}", "Post-request script file" },
  { "< {% %}", " {%\n\t-- lua\n${0}\n%}\n", "Pre-request lua script" },
  { "> {% %}", " {%\n\t-- lua\n${0}\n%}\n", "Post-request lua script" },
}

---@type SourceTable
M.commands = {
  { "run #", "run #", "Run request #name" },
  { "run ../", "run ", "Run requests in file" },
  { "import", "import ", "Import requests" },
}

---@type SourceTable
M.methods = {
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
M.schemes = {
  { "http", "http://" },
  { "https", "https://" },
  { "ws", "ws://" },
  { "wss", "wss://" },
}

---@type SourceTable
M.header_names = {
  { "A-IM", "A-IM: " },
  { "Accept", "Accept: " },
  { "Accept-Additions", "Accept-Additions: " },
  { "Accept-CH", "Accept-CH: " },
  { "Accept-Datetime", "Accept-Datetime: " },
  { "Accept-Encoding", "Accept-Encoding: " },
  { "Accept-Features", "Accept-Features: " },
  { "Accept-Language", "Accept-Language: " },
  { "Accept-Patch", "Accept-Patch: " },
  { "Accept-Post", "Accept-Post: " },
  { "Accept-Ranges", "Accept-Ranges: " },
  { "Accept-Signature", "Accept-Signature: " },
  { "Access-Control-Allow-Credentials", "Access-Control-Allow-Credentials: " },
  { "Access-Control-Allow-Headers", "Access-Control-Allow-Headers: " },
  { "Access-Control-Allow-Methods", "Access-Control-Allow-Methods: " },
  { "Access-Control-Allow-Origin", "Access-Control-Allow-Origin: " },
  { "Access-Control-Expose-Headers", "Access-Control-Expose-Headers: " },
  { "Access-Control-Max-Age", "Access-Control-Max-Age: " },
  { "Access-Control-Request-Headers", "Access-Control-Request-Headers: " },
  { "Access-Control-Request-Method", "Access-Control-Request-Method: " },
  { "Age", "Age: " },
  { "Allow", "Allow: " },
  { "ALPN", "ALPN: " },
  { "Alt-Svc", "Alt-Svc: " },
  { "Alt-Used", "Alt-Used: " },
  { "Alternates", "Alternates: " },
  { "Apply-To-Redirect-Ref", "Apply-To-Redirect-Ref: " },
  { "Authentication-Control", "Authentication-Control: " },
  { "Authentication-Info", "Authentication-Info: " },
  { "Authorization", "Authorization: " },
  { "Available-Dictionary", "Available-Dictionary: " },
  { "Cache-Control", "Cache-Control: " },
  { "Cache-Status", "Cache-Status: " },
  { "Cal-Managed-ID", "Cal-Managed-ID: " },
  { "CalDAV-Timezones", "CalDAV-Timezones: " },
  { "Capsule-Protocol", "Capsule-Protocol: " },
  { "CDN-Cache-Control", "CDN-Cache-Control: " },
  { "CDN-Loop", "CDN-Loop: " },
  { "Cert-Not-After", "Cert-Not-After: " },
  { "Cert-Not-Before", "Cert-Not-Before: " },
  { "Clear-Site-Data", "Clear-Site-Data: " },
  { "Client-Cert", "Client-Cert: " },
  { "Client-Cert-Chain", "Client-Cert-Chain: " },
  { "Close", "Close: " },
  { "Concealed-Auth-Export", "Concealed-Auth-Export: " },
  { "Connection", "Connection: " },
  { "Content-Digest", "Content-Digest: " },
  { "Content-Disposition", "Content-Disposition: " },
  { "Content-Encoding", "Content-Encoding: " },
  { "Content-Language", "Content-Language: " },
  { "Content-Length", "Content-Length: " },
  { "Content-Location", "Content-Location: " },
  { "Content-Range", "Content-Range: " },
  { "Content-Security-Policy", "Content-Security-Policy: " },
  { "Content-Security-Policy-Report-Only", "Content-Security-Policy-Report-Only: " },
  { "Content-Type", "Content-Type: " },
  { "Cookie", "Cookie: " },
  { "Cross-Origin-Embedder-Policy", "Cross-Origin-Embedder-Policy: " },
  { "Cross-Origin-Embedder-Policy-Report-Only", "Cross-Origin-Embedder-Policy-Report-Only: " },
  { "Cross-Origin-Opener-Policy", "Cross-Origin-Opener-Policy: " },
  { "Cross-Origin-Opener-Policy-Report-Only", "Cross-Origin-Opener-Policy-Report-Only: " },
  { "Cross-Origin-Resource-Policy", "Cross-Origin-Resource-Policy: " },
  { "DASL", "DASL: " },
  { "Date", "Date: " },
  { "DAV", "DAV: " },
  { "Delta-Base", "Delta-Base: " },
  { "Deprecation", "Deprecation: " },
  { "Depth", "Depth: " },
  { "Destination", "Destination: " },
  { "Detached-JWS", "Detached-JWS: " },
  { "Dictionary-ID", "Dictionary-ID: " },
  { "DPoP", "DPoP: " },
  { "DPoP-Nonce", "DPoP-Nonce: " },
  { "Early-Data", "Early-Data: " },
  { "ETag", "ETag: " },
  { "Expect", "Expect: " },
  { "Expires", "Expires: " },
  { "Forwarded", "Forwarded: " },
  { "From", "From: " },
  { "Hobareg", "Hobareg: " },
  { "Host", "Host: " },
  { "If", "If: " },
  { "If-Match", "If-Match: " },
  { "If-Modified-Since", "If-Modified-Since: " },
  { "If-None-Match", "If-None-Match: " },
  { "If-Range", "If-Range: " },
  { "If-Schedule-Tag-Match", "If-Schedule-Tag-Match: " },
  { "If-Unmodified-Since", "If-Unmodified-Since: " },
  { "IM", "IM: " },
  { "Include-Referred-Token-Binding-ID", "Include-Referred-Token-Binding-ID: " },
  { "Keep-Alive", "Keep-Alive: " },
  { "Label", "Label: " },
  { "Last-Event-ID", "Last-Event-ID: " },
  { "Last-Modified", "Last-Modified: " },
  { "Link", "Link: " },
  { "Link-Template", "Link-Template: " },
  { "Location", "Location: " },
  { "Lock-Token", "Lock-Token: " },
  { "Max-Forwards", "Max-Forwards: " },
  { "Memento-Datetime", "Memento-Datetime: " },
  { "Meter", "Meter: " },
  { "MIME-Version", "MIME-Version: " },
  { "Negotiate", "Negotiate: " },
  { "NEL", "NEL: " },
  { "OData-EntityId", "OData-EntityId: " },
  { "OData-Isolation", "OData-Isolation: " },
  { "OData-MaxVersion", "OData-MaxVersion: " },
  { "OData-Version", "OData-Version: " },
  { "Optional-WWW-Authenticate", "Optional-WWW-Authenticate: " },
  { "Ordering-Type", "Ordering-Type: " },
  { "Origin", "Origin: " },
  { "Origin-Agent-Cluster", "Origin-Agent-Cluster: " },
  { "OSCORE", "OSCORE: " },
  { "OSLC-Core-Version", "OSLC-Core-Version: " },
  { "Overwrite", "Overwrite: " },
  { "Ping-From", "Ping-From: " },
  { "Ping-To", "Ping-To: " },
  { "Position", "Position: " },
  { "Prefer", "Prefer: " },
  { "Preference-Applied", "Preference-Applied: " },
  { "Priority", "Priority: " },
  { "Proxy-Authenticate", "Proxy-Authenticate: " },
  { "Proxy-Authentication-Info", "Proxy-Authentication-Info: " },
  { "Proxy-Authorization", "Proxy-Authorization: " },
  { "Proxy-Status", "Proxy-Status: " },
  { "Public-Key-Pins", "Public-Key-Pins: " },
  { "Public-Key-Pins-Report-Only", "Public-Key-Pins-Report-Only: " },
  { "Range", "Range: " },
  { "Redirect-Ref", "Redirect-Ref: " },
  { "Referer", "Referer: " },
  { "Referrer-Policy", "Referrer-Policy: " },
  { "Refresh", "Refresh: " },
  { "Replay-Nonce", "Replay-Nonce: " },
  { "Repr-Digest", "Repr-Digest: " },
  { "Retry-After", "Retry-After: " },
  { "Schedule-Reply", "Schedule-Reply: " },
  { "Schedule-Tag", "Schedule-Tag: " },
  { "Sec-Fetch-Dest", "Sec-Fetch-Dest: " },
  { "Sec-Fetch-Mode", "Sec-Fetch-Mode: " },
  { "Sec-Fetch-Site", "Sec-Fetch-Site: " },
  { "Sec-Fetch-User", "Sec-Fetch-User: " },
  { "Sec-Purpose", "Sec-Purpose: " },
  { "Sec-Token-Binding", "Sec-Token-Binding: " },
  { "Sec-WebSocket-Accept", "Sec-WebSocket-Accept: " },
  { "Sec-WebSocket-Extensions", "Sec-WebSocket-Extensions: " },
  { "Sec-WebSocket-Key", "Sec-WebSocket-Key: " },
  { "Sec-WebSocket-Protocol", "Sec-WebSocket-Protocol: " },
  { "Sec-WebSocket-Version", "Sec-WebSocket-Version: " },
  { "Server", "Server: " },
  { "Server-Timing", "Server-Timing: " },
  { "Set-Cookie", "Set-Cookie: " },
  { "Signature", "Signature: " },
  { "Signature-Input", "Signature-Input: " },
  { "SLUG", "SLUG: " },
  { "SoapAction", "SoapAction: " },
  { "Status-URI", "Status-URI: " },
  { "Strict-Transport-Security", "Strict-Transport-Security: " },
  { "Sunset", "Sunset: " },
  { "TCN", "TCN: " },
  { "TE", "TE: " },
  { "Timeout", "Timeout: " },
  { "Topic", "Topic: " },
  { "Traceparent", "Traceparent: " },
  { "Tracestate", "Tracestate: " },
  { "Trailer", "Trailer: " },
  { "Transfer-Encoding", "Transfer-Encoding: " },
  { "TTL", "TTL: " },
  { "Upgrade", "Upgrade: " },
  { "Urgency", "Urgency: " },
  { "Use-As-Dictionary", "Use-As-Dictionary: " },
  { "User-Agent", "User-Agent: " },
  { "Variant-Vary", "Variant-Vary: " },
  { "Vary", "Vary: " },
  { "Via", "Via: " },
  { "Want-Content-Digest", "Want-Content-Digest: " },
  { "Want-Repr-Digest", "Want-Repr-Digest: " },
  { "WWW-Authenticate", "WWW-Authenticate: " },
  { "X-Content-Type-Options", "X-Content-Type-Options: " },
  { "X-Request-Type", "X-Request-Type: " },
  { "X-Frame-Options", "X-Frame-Options: " },
  { "*", "*: " },
  { "Activate-Storage-Access", "Activate-Storage-Access: " },
  { "AMP-Cache-Transform", "AMP-Cache-Transform: " },
  { "CMCD-Object", "CMCD-Object: " },
  { "CMCD-Request", "CMCD-Request: " },
  { "CMCD-Session", "CMCD-Session: " },
  { "CMCD-Status", "CMCD-Status: " },
  { "CMSD-Dynamic", "CMSD-Dynamic: " },
  { "CMSD-Static", "CMSD-Static: " },
  { "Configuration-Context", "Configuration-Context: " },
  { "CTA-Common-Access-Token", "CTA-Common-Access-Token: " },
  { "EDIINT-Features", "EDIINT-Features: " },
  { "Isolation", "Isolation: " },
  { "Permissions-Policy", "Permissions-Policy: " },
  { "Repeatability-Client-ID", "Repeatability-Client-ID: " },
  { "Repeatability-First-Sent", "Repeatability-First-Sent: " },
  { "Repeatability-Request-ID", "Repeatability-Request-ID: " },
  { "Repeatability-Result", "Repeatability-Result: " },
  { "Reporting-Endpoints", "Reporting-Endpoints: " },
  { "Sec-Fetch-Storage-Access", "Sec-Fetch-Storage-Access: " },
  { "Sec-GPC", "Sec-GPC: " },
  { "Surrogate-Capability", "Surrogate-Capability: " },
  { "Surrogate-Control", "Surrogate-Control: " },
  { "Timing-Allow-Origin", "Timing-Allow-Origin: " },
}

---@type SourceTable
M.header_values = {
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
  { "application/graphql-response+json" },
  { "GraphQL" },
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
M.metadata = {
  { "prompt", "prompt ", "Prompt" },
  { "secret", "secret ", "Secret prompt" },
  { "curl", "curl", "Curl flag" },
  { "curl-global", "curl-global", "Curl global flag" },
  { "grpc", "grpc", "Grpc flag" },
  { "grpc-global", "Grpc-global", "Grpc global flag" },
  { "accept", "accept chunked", "Accept chunked responses" },
  { "env-stdin-cmd", "env-stdin-cmd ", "Set env variable with external cmd" },
  { "env-json-key", "env-json-key ", "Set env variable with json key" },
  { "stdin-cmd", "env-stdin-cmd ", "Run external command" },
  { "jq", "jq ", "Filter response body with jq" },
}

---@type SourceTable
M.curl = {
  { "curl-compressed", "curl-compressed", "Decompress response" },
  { "curl-location", "curl-location", "Follow redirects" },
  { "curl-no-buffer", "curl-no-buffer", "Disable buffering" },
  { "curl-insecure", "curl-insecure", "Skip secure connection verification" },
  { "curl-data-urlencode", "curl-data-urlencode", "Urlencode payload" },
}

---@type SourceTable
M.grpc = {
  { "grpc-import-path", "grpc-import-path", "Proto import path" },
  { "grpc-proto", "grpc-proto", "Proto file" },
  { "grpc-protoset", "grpc-protoset", "Protoset file" },
  { "grpc-plaintext", "grpc-plaintext", "No TLS" },
  { "grpc-v", "grpc-verbose", "Verbose" },
}

---@type SourceTable
M.script_client = {
  { "client.global.get", "client.global.get(${1:varName})$0", "Get a  global variable" },
  { "client.global.set", "client.global.set(${1:varName}, ${2:value})$0", "Set a global variable" },
  { "client.responses", 'client.responses["${1:name}"]$0', "Previous responses" },
  { "client.log", "client.log(${1:message})$0", "Log message" },
  { "client.test", "client.test(${1:name}, ${2:fn})$0", "Define a test suite" },
  { "client.assert", "client.assert(${1:value}, ${2:message?})$0", "Checks if the value is truthy" },
  { "client.isEmpty", "client.isEmpty()$0", "Check if global variables are empty" },
  { "client.clear", "client.clear(${1:varName})$0", "Clear a global variable" },
  { "client.clearAll", "client.clearAll()$0", "Clear all global variables" },
  { "client.exit", "client.exit()$0", "Exit script" },
}

---@type SourceTable
M.script_request = {
  { "request.variables.set", "request.variables.set(${1:varName}, ${2:value})$0", "Set a request variable" },
  { "request.variables.get", "request.variables.get(${1:varName})$0", "Get a request variable" },
  { "request.headers.all", "request.headers.all()$0", "Get all request headers" },
  { "name", "name()$0", "Get header name" },
  {
    "getRawValue",
    "getRawValue()$0",
    "Get raw request header value",
  },
  {
    "tryGetSubstituted",
    "tryGetSubstituted()$0",
    "Get substituted request header value",
  },
  {
    "request.headers.findByName",
    "request.headers.findByName(${1:name})$0",
    "Find request header by name",
  },
  { "request.body.getRaw", "request.body.getRaw()$0", "Get raw request body" },
  {
    "request.body.tryGetSubstituted",
    "request.body.tryGetSubstituted()$0",
    "Get substituted request body",
  },
  {
    "request.body.getComputed",
    "request.body.getComputed()$0",
    "Get computed request body",
  },
  { "request.environment.get", "request.environment.get(${1:varName})$0", "Get environment variable" },
  { "request.method", "request.method()$0", "Get request method" },
  { "request.url.getRaw", "request.url.getRaw()$0", "Get raw request URL" },
  {
    "request.url.tryGetSubstituted",
    "request.url.tryGetSubstituted()$0",
    "Get substituted request URL",
  },
  { "request.skip", "request.skip()$0", "Skip request" },
  { "request.replay", "request.replay()$0", "Replay request" },
  { "request.iteration", "request.iteration()$0", "The current count of request replays" },
}

---@type SourceTable
M.script_response = {
  { "response.responseCode", "response.responseCode()$0", "Get response code" },
  { "response.status", "response.status()$0", "Get response status" },
  { "response.code", "response.code()$0", "Get request code" },
  { "response.url", "response.url()$0", "Get response URL" },
  { "response.body", "response.body()$0", "Get response body" },
  { "response.json", "response.json()$0", "Get response json" },
  { "response.errors", "response.errors()$0", "Get response errors" },
  { "response.headers.all", "response.headers.all()$0", "Get all response headers" },
  { "valueOf", "valueOf()$0", "Get response header value" },
  { "valuesOf", "valuesOf()$0", "Get all response header values" },
  { "response.cookies", "response.cookies()$0", "Get response cookies" },
  { "response.headers", "response.headers()$0", "Get response headers" },
  { "response.headers_tbl", "response.headers_tbl()$0", "Get response headers table" },
}

---@type SourceTable
M.script_assert = {

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

return M
