---Shared markdown formatting for Kulala UI views.
local Json = require("kulala.utils.json")

local M = {}

---@param s string
---@return string
function M.trim(s)
  return vim.trim(s or "")
end

---Insert a blank line after ATX headings (`#` …).
---Skips lines inside fenced code blocks.
---@param s string
---@return string
function M.normalize_headings(s)
  if s == "" then return s end

  local lines = vim.split(s, "\n", { plain = true })
  local result = {}
  local in_fence = false

  for i, line in ipairs(lines) do
    table.insert(result, line)

    if line:match("^```") then
      in_fence = not in_fence
    elseif not in_fence and line:match("^#+%s") and lines[i + 1] ~= "" then
      table.insert(result, "")
    end
  end

  return table.concat(result, "\n")
end

---Escape inline markdown (headings, lists, etc.); wraps in backticks.
---@param s string
---@return string
function M.md_escape_cell(s)
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

---Escape table cell text; use inline code for markdown-special content so values
---like `*/*` render literally, otherwise keep plain text for column alignment.
---@param s string
---@return string
function M.md_table_cell(s)
  s = tostring(s):gsub("\r", ""):gsub("\n", "<br>")
  if s:find("[%*_\\|]") then return M.md_escape_cell(s) end
  return s
end

---@param s string
---@return number
local function display_width(s)
  return vim.api.nvim_strwidth(s)
end

---@param rows string[][] row 1 = plain header labels; row 2+ = rendered cells
---@param align? "l"|"r" -- right-align columns after the first (GFM `---:`)
---@return string
function M.md_table(rows, align)
  if #rows == 0 then return "" end
  local ncols = #rows[1]
  local widths = {}
  for _, row in ipairs(rows) do
    for i = 1, ncols do
      widths[i] = math.max(widths[i] or 0, display_width(tostring(row[i] or "")))
    end
  end

  local function col_width(col_idx)
    local w = math.max(3, widths[col_idx] or 3)
    if align == "r" and col_idx > 1 then
      w = math.max(4, w) -- GFM right-align needs at least `---:` (3 dashes + colon)
    end
    return w
  end

  ---@param col string
  ---@param col_idx number
  local function fmt_cell(col, col_idx)
    col = tostring(col or "")
    local w = col_width(col_idx)
    local dw = display_width(col)
    if dw > w then
      widths[col_idx] = dw
      w = col_width(col_idx)
      dw = display_width(col)
    end
    local pad = math.max(0, w - dw)
    if align == "r" and col_idx > 1 then return string.rep(" ", pad) .. col end
    return col .. string.rep(" ", pad)
  end

  ---@param col_idx number
  local function fmt_sep(col_idx)
    local w = col_width(col_idx)
    if align == "r" and col_idx > 1 then return fmt_cell(string.rep("-", w - 1) .. ":", col_idx) end
    return fmt_cell(string.rep("-", w), col_idx)
  end

  local function fmt_row(row)
    local cells = {}
    for i = 1, ncols do
      cells[i] = fmt_cell(row[i] or "", i)
    end
    return "| " .. table.concat(cells, " | ") .. " |"
  end

  local sep_cells = {}
  for i = 1, ncols do
    sep_cells[i] = fmt_sep(i)
  end

  local lines = { fmt_row(rows[1]), "| " .. table.concat(sep_cells, " | ") .. " |" }
  for r = 2, #rows do
    table.insert(lines, fmt_row(rows[r]))
  end
  return table.concat(lines, "\n")
end

---@param v string|table|nil
---@return string
local function header_value(v)
  if v == nil then return "" end
  if type(v) == "table" then
    if vim.islist(v) then return table.concat(vim.tbl_map(tostring, v), ", ") end
    return vim.inspect(v)
  end
  return tostring(v)
end

---Prefer raw header text (same source as the legacy headers pane); fall back to parsed table.
---@param r Response
---@return string|table|nil
function M.response_headers_source(r)
  if type(r.headers) == "string" and M.trim(r.headers) ~= "" then return r.headers end
  if type(r.headers_tbl) == "table" and next(r.headers_tbl) then return r.headers_tbl end
  return nil
end

---@param headers table<string, string|table>|string|nil
---@return string[][]
function M.headers_rows(headers)
  local rows = { { "Header", "Value" } }
  if type(headers) == "string" then
    for line in vim.gsplit(headers, "\n", { plain = true, trimempty = true }) do
      local k, v = line:match("^([^:]+):%s*(.*)$")
      if k then table.insert(rows, { M.md_table_cell(k), M.md_escape_cell(v) }) end
    end
    return rows
  end
  if type(headers) ~= "table" then return rows end
  local keys = vim.tbl_keys(headers)
  table.sort(keys, function(a, b)
    return a:lower() < b:lower()
  end)
  for _, k in ipairs(keys) do
    table.insert(rows, { M.md_table_cell(k), M.md_escape_cell(header_value(headers[k])) })
  end
  return rows
end

---@param headers table<string, string|table>|string|nil
---@return string
function M.format_headers_table(headers)
  local rows = M.headers_rows(headers)
  if #rows < 2 then return "_No headers_\n" end
  return M.md_table(rows) .. "\n"
end

---@param s string
---@return string
function M.pretty_maybe_json(s)
  if not s or s == "" then return s end
  if vim.fn.executable("jq") == 1 then
    local job = vim.system({ "jq", "-M", "." }, { stdin = s, text = true }):wait()
    if job.code == 0 and job.stdout and M.trim(job.stdout) ~= "" then return M.trim(job.stdout) end
  end
  local t = Json.parse(s, { verbose = false })
  if t ~= nil then return vim.inspect(t) end
  return s
end

---@param lang string
---@param body string
---@return string
function M.fenced(lang, body)
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
function M.body_fence_lang(body)
  local trimmed = M.trim(body)
  if trimmed == "" then return "", "text" end
  if Json.parse(trimmed, { verbose = false }) ~= nil then return M.pretty_maybe_json(trimmed), "json" end
  return body, "text"
end

---@param parts string[]
---@param heading string
---@param content string|nil
function M.add_section(parts, heading, content)
  content = M.trim(content or "")
  if content == "" then return end
  table.insert(parts, heading)
  table.insert(parts, content)
  table.insert(parts, "")
end

---@param tm table|nil
---@return string[][]
function M.timings_rows(tm)
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
        table.insert(rows, { M.md_table_cell(e.name), M.md_table_cell(("%.3f"):format(sec * 1000)) })
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
      table.insert(rows, { M.md_table_cell(label), M.md_table_cell(("%.3f"):format(ms)) })
    end
  end
  return rows
end

---@param tm table|nil
---@return string
function M.format_timings(tm)
  local rows = M.timings_rows(tm)
  if #rows < 2 then return "" end
  return M.md_table(rows, "r") .. "\n"
end

---@param stats table|string|nil
---@return string
function M.format_stats_table(stats)
  if type(stats) ~= "table" then return "" end
  local tm = stats.timings
  if type(tm) == "table" then return M.format_timings(tm) end
  return ""
end

---@param trace string
---@return string connection, string request_hdrs, string response_hdrs, string other
function M.split_curl_trace(trace)
  local connection, request_hdrs, response_hdrs, other = {}, {}, {}, {}
  for line in vim.gsplit(trace or "", "\n", { plain = true }) do
    if line:match("^%*") then
      table.insert(connection, line:sub(2))
    elseif line:match("^>") then
      table.insert(request_hdrs, line:sub(2))
    elseif line:match("^<") then
      table.insert(response_hdrs, line:sub(2))
    elseif M.trim(line) ~= "" then
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
function M.format_connection_trace(trace)
  trace = M.trim(trace or "")
  if trace == "" then return "" end

  local conn, req_hdr, res_hdr, other = M.split_curl_trace(trace)
  local parts = {}

  local function trace_header_rows(block)
    local rows = { { "Header", "Value" } }
    local status_line
    for line in vim.gsplit(block, "\n", { plain = true }) do
      local text = M.trim(line)
      if text:match("^HTTP/") then
        status_line = text
      else
        local k, v = text:match("^([^:]+):%s*(.*)$")
        if k then table.insert(rows, { M.md_table_cell(k), M.md_table_cell(v) }) end
      end
    end
    return rows, status_line
  end

  if conn ~= "" then
    table.insert(parts, "### Connection & TLS\n")
    for line in vim.gsplit(conn, "\n", { plain = true }) do
      local text = M.trim(line)
      if text ~= "" then table.insert(parts, ("- %s"):format(M.md_escape_cell(text))) end
    end
    table.insert(parts, "")
  end

  if req_hdr ~= "" then
    table.insert(parts, "### Request (from trace)\n")
    local rows, status = trace_header_rows(req_hdr)
    if status then table.insert(parts, ("**Request line:** %s\n"):format(M.md_escape_cell(status))) end
    if #rows > 1 then table.insert(parts, M.md_table(rows) .. "\n") end
  end

  if res_hdr ~= "" then
    table.insert(parts, "### Response (from trace)\n")
    local rows, status = trace_header_rows(res_hdr)
    if status then table.insert(parts, ("**Status:** %s\n"):format(M.md_escape_cell(status))) end
    if #rows > 1 then table.insert(parts, M.md_table(rows) .. "\n") end
  end

  if other ~= "" then
    table.insert(parts, "### Trace (other)\n")
    table.insert(parts, M.fenced("text", other))
  end

  return table.concat(parts, "\n")
end

---@param r Response
---@return string
function M.format_headers_view(r)
  return ("### Response headers\n%s"):format(M.format_headers_table(M.response_headers_source(r)))
end

---@param body string|nil
---@return string
function M.format_body_view(body)
  body = body or ""
  if body:match("^No response body %(check Verbose output%)") then return "### Response body\n_No response body_\n" end
  local content, lang = M.body_fence_lang(body)
  return ("### Response body\n%s"):format(M.fenced(lang, content))
end

---@param r Response
---@param body? string optional pre-formatted body (e.g. after external formatter)
---@return string
function M.format_headers_body_view(r, body)
  return M.format_headers_view(r) .. "\n" .. M.format_body_view(body or r.body)
end

---@param pre string|nil
---@param post string|nil
---@return string
function M.format_script_sections(pre, post)
  local parts = {}
  pre, post = pre or "", post or ""
  if M.trim(pre) ~= "" then
    table.insert(parts, "### Pre-request script\n")
    table.insert(parts, M.fenced("text", pre))
  end
  if M.trim(post) ~= "" then
    table.insert(parts, "### Post-request script\n")
    table.insert(parts, M.fenced("text", post))
  end
  if #parts == 0 then return "_No script output_\n" end
  return table.concat(parts, "\n")
end

---@param r Response
---@return string
function M.format_script_output(r)
  return M.format_script_sections(r.script_pre_output, r.script_post_output)
end

return M
