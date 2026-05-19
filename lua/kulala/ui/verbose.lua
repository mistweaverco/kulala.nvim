---Markdown verbose view (curl `-v`-style detail, structured for readability).
local Json = require("kulala.utils.json")

local M = {}

---@param s string
---@return string
local function trim(s)
  return vim.trim(s or "")
end

---Escape cell text and wrap in inline code so markdown does not interpret `*`, `_`, etc.
---@param s string
---@return string
local function md_escape_cell(s)
  s = tostring(s):gsub("|", "\\|"):gsub("\r", ""):gsub("\n", "<br>")
  local max_run = 0
  local run = 0
  for i = 1, #s do
    if s:byte(i) == 96 then
      run = run + 1
      max_run = math.max(max_run, run)
    else
      run = 0
    end
  end
  local fence = string.rep("`", max_run + 1)
  return fence .. s .. fence
end

---@param rows string[][] row 1 = plain header labels; row 2+ = rendered cells (e.g. backtick-wrapped)
---@param align? "l"|"r" -- right-align columns after the first (GFM `---:`)
---@return string
local function md_table(rows, align)
  if #rows == 0 then return "" end
  local ncols = #rows[1]
  local widths = {}
  for _, row in ipairs(rows) do
    for i = 1, ncols do
      widths[i] = math.max(widths[i] or 0, #(tostring(row[i] or "")))
    end
  end

  ---@param col string
  ---@param col_idx number
  local function fmt_cell(col, col_idx)
    col = tostring(col or "")
    local pad = widths[col_idx] - #col
    local right = align == "r" and col_idx > 1
    if right then return string.rep(" ", pad) .. col end
    return col .. string.rep(" ", pad)
  end

  local function fmt_row(row)
    local cells = {}
    for i = 1, ncols do
      cells[i] = fmt_cell(row[i] or "", i)
    end
    return "| " .. table.concat(cells, " | ") .. " |"
  end

  local sep = {}
  for i = 1, ncols do
    local w = math.max(3, widths[i] or 3)
    if align == "r" and i > 1 then
      sep[i] = string.rep("-", w) .. ":"
    else
      sep[i] = string.rep("-", w)
    end
  end

  local lines = { fmt_row(rows[1]), "| " .. table.concat(sep, " | ") .. " |" }
  for r = 2, #rows do
    table.insert(lines, fmt_row(rows[r]))
  end
  return table.concat(lines, "\n")
end

---@param headers table<string, string|table>|string|nil
---@return string[][]
local function headers_rows(headers)
  local rows = { { "Header", "Value" } }
  if type(headers) == "string" then
    for line in vim.gsplit(headers, "\n", { plain = true, trimempty = true }) do
      local k, v = line:match("^([^:]+):%s*(.*)$")
      if k then table.insert(rows, { md_escape_cell(k), md_escape_cell(v) }) end
    end
    return rows
  end
  if type(headers) ~= "table" then return rows end
  local keys = vim.tbl_keys(headers)
  table.sort(keys, function(a, b)
    return a:lower() < b:lower()
  end)
  for _, k in ipairs(keys) do
    local v = headers[k]
    if type(v) == "table" then v = table.concat(v, "\n") end
    table.insert(rows, { md_escape_cell(k), md_escape_cell(v) })
  end
  return rows
end

---@param headers table<string, string|table>|string|nil
---@return string
local function format_headers_table(headers)
  local rows = headers_rows(headers)
  if #rows < 2 then return "_No headers_\n" end
  return md_table(rows) .. "\n"
end

---@param s string
---@return string
local function pretty_maybe_json(s)
  if not s or s == "" then return s end
  if vim.fn.executable("jq") == 1 then
    local job = vim.system({ "jq", "-M", "." }, { stdin = s, text = true }):wait()
    if job.code == 0 and job.stdout and trim(job.stdout) ~= "" then return trim(job.stdout) end
  end
  local t = Json.parse(s, { verbose = false })
  if t ~= nil then return vim.inspect(t) end
  return s
end

---@param lang string
---@param body string
---@return string
local function fenced(lang, body)
  body = body or ""
  if body == "" then return "_Empty_\n" end
  local fence = "```"
  while body:find(fence, 1, true) do
    fence = fence .. "`"
  end
  return fence .. lang .. "\n" .. body .. "\n" .. fence .. "\n"
end

---@param body string
---@return string, string lang
local function body_fence_lang(body)
  local trimmed = trim(body)
  if trimmed == "" then return "", "text" end
  if Json.parse(trimmed, { verbose = false }) ~= nil then return pretty_maybe_json(trimmed), "json" end
  return body, "text"
end

---@param tm table|nil
---@return string[][]
local function timings_rows(tm)
  local rows = { { "Phase", "ms" } }
  if type(tm) ~= "table" then return rows end

  local order = {
    { "dns", "DNS" },
    { "namelookup", "DNS" },
    { "tcp", "TCP" },
    { "connect", "TCP connect" },
    { "tls", "TLS" },
    { "appconnect", "TLS handshake" },
    { "request", "Request" },
    { "pretransfer", "Pre-transfer" },
    { "redirect", "Redirect" },
    { "firstByte", "TTFB" },
    { "starttransfer", "Start transfer" },
    { "startTransfer", "Start transfer" },
    { "total", "Total" },
  }

  local seen = {}
  if vim.islist(tm) then
    for _, e in ipairs(tm) do
      if type(e) == "table" and e.name and e.duration ~= nil and not seen[e.name] then
        seen[e.name] = true
        local sec = tonumber(e.duration) or 0
        table.insert(rows, { md_escape_cell(e.name), md_escape_cell(("%.3f"):format(sec * 1000)) })
      end
    end
    return rows
  end

  local max_val = 0
  for _, pair in ipairs(order) do
    local v = tm[pair[1]]
    if type(v) == "number" then max_val = math.max(max_val, v) end
  end
  local scale_seconds = max_val > 0 and max_val < 30

  for _, pair in ipairs(order) do
    local key, label = pair[1], pair[2]
    local v = tm[key]
    if v ~= nil and not seen[label] then
      seen[label] = true
      local ms = tonumber(v) or 0
      if scale_seconds then ms = ms * 1000 end
      table.insert(rows, { md_escape_cell(label), md_escape_cell(("%.3f"):format(ms)) })
    end
  end
  return rows
end

---@param tm table|nil
---@return string
local function format_timings(tm)
  local rows = timings_rows(tm)
  if #rows < 2 then return "" end
  return md_table(rows, "r") .. "\n"
end

---@param stats table|string|nil
---@return string
local function format_stats_table(stats)
  if type(stats) ~= "table" then return "" end
  local tm = stats.timings
  if type(tm) == "table" then return format_timings(tm) end
  return ""
end

---@param trace string
---@return string connection, string request_hdrs, string response_hdrs, string other
local function split_curl_trace(trace)
  local connection, request_hdrs, response_hdrs, other = {}, {}, {}, {}
  for line in vim.gsplit(trace or "", "\n", { plain = true }) do
    if line:match("^%*") then
      table.insert(connection, line:sub(2))
    elseif line:match("^>") then
      table.insert(request_hdrs, line:sub(2))
    elseif line:match("^<") then
      table.insert(response_hdrs, line:sub(2))
    elseif trim(line) ~= "" then
      table.insert(other, line)
    end
  end
  local join = function(t)
    if #t == 0 then return "" end
    return table.concat(t, "\n")
  end
  return join(connection), join(request_hdrs), join(response_hdrs), join(other)
end

---@param trace string|nil
---@return string
local function format_connection_trace(trace)
  trace = trim(trace or "")
  if trace == "" then return "" end

  local conn, req_hdr, res_hdr, other = split_curl_trace(trace)
  local parts = {}

  local function trace_header_rows(block)
    local rows = { { "Header", "Value" } }
    local status_line
    for line in vim.gsplit(block, "\n", { plain = true }) do
      local text = trim(line)
      if text:match("^HTTP/") then
        status_line = text
      else
        local k, v = text:match("^([^:]+):%s*(.*)$")
        if k then table.insert(rows, { md_escape_cell(k), md_escape_cell(v) }) end
      end
    end
    return rows, status_line
  end

  if conn ~= "" then
    table.insert(parts, "### Connection & TLS\n")
    for line in vim.gsplit(conn, "\n", { plain = true }) do
      local text = trim(line)
      if text ~= "" then table.insert(parts, ("- %s"):format(md_escape_cell(text))) end
    end
    table.insert(parts, "")
  end

  if req_hdr ~= "" then
    table.insert(parts, "### Request (from trace)\n")
    local rows, status = trace_header_rows(req_hdr)
    if status then table.insert(parts, ("**Request line:** %s\n"):format(md_escape_cell(status))) end
    if #rows > 1 then table.insert(parts, md_table(rows) .. "\n") end
  end

  if res_hdr ~= "" then
    table.insert(parts, "### Response (from trace)\n")
    local rows, status = trace_header_rows(res_hdr)
    if status then table.insert(parts, ("**Status:** %s\n"):format(md_escape_cell(status))) end
    if #rows > 1 then table.insert(parts, md_table(rows) .. "\n") end
  end

  if other ~= "" then
    table.insert(parts, "### Trace (other)\n")
    table.insert(parts, fenced("text", other))
  end

  return table.concat(parts, "\n")
end

---@param body table|nil
---@return string, string
local function format_hop_body(body)
  if type(body) ~= "table" then return "", "text" end
  if body.type == "json" and body.content ~= nil then
    local ok, s = pcall(vim.json.encode, body.content)
    if ok and s then return pretty_maybe_json(s), "json" end
    return vim.inspect(body.content), "text"
  end
  if body.type == "text" and body.content then
    local lang, content = body_fence_lang(tostring(body.content))
    return content, lang
  end
  return "", "text"
end

---@param hop table
---@param index number
---@param title string
---@return string
local function format_hop(hop, index, title)
  if type(hop) ~= "table" then return "" end
  local parts = {}
  table.insert(parts, ("## %s %d — HTTP %s\n"):format(title, index, md_escape_cell(tostring(hop.status or "?"))))
  if hop.url then table.insert(parts, ("**URL:** %s\n"):format(md_escape_cell(hop.url))) end

  local tm = format_timings(hop.timings)
  if tm ~= "" then
    table.insert(parts, "### Timings\n")
    table.insert(parts, tm)
  end

  if hop.headers then
    table.insert(parts, "### Response headers\n")
    table.insert(parts, format_headers_table(hop.headers))
  end

  local body, lang = format_hop_body(hop.body)
  if body ~= "" then
    table.insert(parts, "### Response body\n")
    table.insert(parts, fenced(lang, body))
  end

  local trace = format_connection_trace(hop.verboseTrace)
  if trace ~= "" then table.insert(parts, trace) end

  return table.concat(parts, "\n")
end

---kulala-core includes the final response as the last hop.
---@param chain table[]
---@return table[]|nil
local function redirect_chain_without_final(chain)
  if not vim.islist(chain) or #chain < 2 then return nil end
  local out = {}
  for i = 1, #chain - 1 do
    out[i] = chain[i]
  end
  return out
end

---@param parts string[]
---@param heading string
---@param content string|nil
local function add_section(parts, heading, content)
  content = trim(content or "")
  if content == "" then return end
  table.insert(parts, heading)
  table.insert(parts, content)
  table.insert(parts, "")
end

---@param r Response
---@return string
function M.format(r)
  local parts = {}
  local method = r.method or "?"
  local url = (r.request and r.request.url) or r.url or "?"
  table.insert(parts, ("# %s %s\n"):format(md_escape_cell(method), md_escape_cell(url)))

  if r.errors and trim(r.errors) ~= "" then add_section(parts, "## Errors\n", fenced("text", trim(r.errors))) end

  table.insert(parts, "## Request\n")
  table.insert(parts, ("%s %s\n"):format(md_escape_cell(method), md_escape_cell((r.request and r.request.url) or url)))

  local req_headers = r.request and r.request.headers_tbl
  if req_headers and next(req_headers) then
    table.insert(parts, "### Request headers\n")
    table.insert(parts, format_headers_table(req_headers))
  end

  local req_body = r.request and r.request.body
  if type(req_body) == "string" and trim(req_body) ~= "" then
    local content, lang = body_fence_lang(req_body)
    table.insert(parts, "### Request body\n")
    table.insert(parts, fenced(lang, content))
  end

  local chain = r._kulala_redirect_chain
  local intermediate = chain and redirect_chain_without_final(chain)
  if intermediate and #intermediate > 0 then
    table.insert(parts, "## Redirect chain\n")
    for i, hop in ipairs(intermediate) do
      table.insert(parts, format_hop(hop, i, "Hop"))
    end
  end

  table.insert(parts, ("## Response — HTTP %s\n"):format(md_escape_cell(tostring(r.response_code or "?"))))

  if r.headers and trim(r.headers) ~= "" then
    table.insert(parts, "### Response headers\n")
    table.insert(parts, format_headers_table(r.headers_tbl and next(r.headers_tbl) and r.headers_tbl or r.headers))
  end

  local body = r.body or ""
  if body:match("^No response body %(check Verbose output%)") then
    table.insert(parts, "### Response body\n")
    table.insert(parts, "_No response body_\n")
  else
    local content, lang = body_fence_lang(body)
    table.insert(parts, "### Response body\n")
    table.insert(parts, fenced(lang, content))
  end

  local trace = r._kulala_verbose_trace or r.verboseTrace
  local conn = format_connection_trace(trace)
  if conn ~= "" then
    table.insert(parts, "## Connection trace\n")
    table.insert(parts, conn)
  end

  local st = format_stats_table(r.stats)
  if st ~= "" then
    table.insert(parts, "## Transfer timings\n")
    table.insert(parts, st)
  end

  local script_chunks = {}
  if r.script_pre_output and trim(r.script_pre_output) ~= "" then
    table.insert(script_chunks, "### Pre-request script\n")
    table.insert(script_chunks, fenced("text", r.script_pre_output))
  end
  if r.script_post_output and trim(r.script_post_output) ~= "" then
    table.insert(script_chunks, "### Post-request script\n")
    table.insert(script_chunks, fenced("text", r.script_post_output))
  end
  if #script_chunks > 0 then add_section(parts, "## Script output\n", table.concat(script_chunks, "\n")) end

  return trim(table.concat(parts, "\n"))
end

---Legacy curl backend: `errors` holds `-v` stderr; body is the response payload.
---@param r Response
---@return string
function M.format_legacy(r)
  local parts = {}
  local method = r.method or "?"
  local url = r.url or "?"
  table.insert(parts, ("# %s %s\n"):format(md_escape_cell(method), md_escape_cell(url)))

  local trace = trim(r.errors or "")
  if trace ~= "" then table.insert(parts, format_connection_trace(trace)) end

  local body = r.body or ""
  if trim(body) ~= "" and not body:match("^No response body") then
    local content, lang = body_fence_lang(body)
    table.insert(parts, "## Response body\n")
    table.insert(parts, fenced(lang, content))
  end

  return trim(table.concat(parts, "\n"))
end

return M
