local Json = require("kulala.utils.json")

local M = {}

---Pretty-print JSON when possible (`jq`, else decode + `vim.inspect`).
---@param s string
---@return string
local function pretty_maybe_json(s)
  if not s or s == "" then return s end
  if vim.fn.executable("jq") == 1 then
    local job = vim.system({ "jq", "-M", "." }, { stdin = s, text = true }):wait()
    if job.code == 0 and job.stdout and vim.trim(job.stdout) ~= "" then return vim.trim(job.stdout) end
  end
  local t = Json.parse(s, { verbose = false })
  if t ~= nil then return vim.inspect(t) end
  return s
end

---@param stats table|string|nil
---@return string
local function format_stats(stats)
  if type(stats) ~= "table" then return "" end
  local lines = {}
  if stats.response_code ~= nil then
    table.insert(lines, ("response_code: %s"):format(tostring(stats.response_code)))
  end
  if stats.timings and vim.islist(stats.timings) then
    table.insert(lines, "timings:")
    for _, e in ipairs(stats.timings) do
      if type(e) == "table" and e.name ~= nil then
        table.insert(lines, ("  %s: %s s"):format(tostring(e.name), tostring(e.duration)))
      end
    end
  end
  return table.concat(lines, "\n")
end

---@param tm table|nil
---@return string
local function format_hop_timings(tm)
  if type(tm) ~= "table" then return "" end
  local order = { "dns", "tcp", "tls", "request", "redirect", "firstByte", "startTransfer", "total" }
  local parts = {}
  for _, k in ipairs(order) do
    local v = tm[k]
    if v ~= nil then table.insert(parts, ("%s=%s"):format(k, tostring(v))) end
  end
  return table.concat(parts, "  ")
end

---@param h table|nil
---@return string
local function format_hop_headers(h)
  if type(h) ~= "table" then return "" end
  local lines = {}
  for k, v in pairs(h) do
    local val = type(v) == "table" and table.concat(v, "\n") or tostring(v)
    table.insert(lines, ("%s: %s"):format(k, val))
  end
  table.sort(lines)
  return table.concat(lines, "\n")
end

---@param body table|nil
---@return string
local function format_hop_body(body)
  if type(body) ~= "table" then return "" end
  if body.type == "json" and body.content ~= nil then
    local ok, s = pcall(vim.json.encode, body.content)
    if ok and s then return pretty_maybe_json(s) end
    return vim.inspect(body.content)
  end
  if body.type == "text" and body.content then return pretty_maybe_json(tostring(body.content)) end
  return ""
end

---@param chain table[]
---@return string
local function format_redirect_chain(chain)
  local chunks = {}
  for i, hop in ipairs(chain) do
    if type(hop) == "table" then
      table.insert(chunks, ("--- Hop %s ---"):format(tostring(i)))
      table.insert(chunks, ("HTTP %s"):format(tostring(hop.status or "?")))
      if hop.url then table.insert(chunks, ("URL: %s"):format(hop.url)) end
      local tm = format_hop_timings(hop.timings)
      if tm ~= "" then table.insert(chunks, ("Timings: %s"):format(tm)) end
      local hdr = format_hop_headers(hop.headers)
      if hdr ~= "" then
        table.insert(chunks, "Headers:")
        table.insert(chunks, hdr)
      end
      local b = format_hop_body(hop.body)
      if b ~= "" then
        table.insert(chunks, "Body:")
        table.insert(chunks, b)
      end
      table.insert(chunks, "")
    end
  end
  return vim.trim(table.concat(chunks, "\n"))
end

---kulala-core includes the final response as the last hop; that is already shown under Response / headers / body.
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

---Multi-line verbose view (kulala-core has no curl `-v` trace; body is often one-line JSON).
---@param r Response
---@return string
function M.format(r)
  local parts = {}

  local function add(title, text)
    text = vim.trim(text or "")
    if text == "" then return end
    table.insert(parts, title)
    table.insert(parts, text)
    table.insert(parts, "")
  end

  if r.errors and vim.trim(r.errors) ~= "" then add("=== Errors ===", r.errors) end

  add("=== Request ===", ("%s %s"):format(r.method or "?", r.url or "?"))

  local req_body = r.request and r.request.body
  if type(req_body) == "string" and vim.trim(req_body) ~= "" then
    add("=== Request body ===", pretty_maybe_json(req_body))
  end

  local chain = r._kulala_redirect_chain
  local intermediate = chain and redirect_chain_without_final(chain)
  if intermediate and #intermediate > 0 then add("=== Redirect chain ===", format_redirect_chain(intermediate)) end

  add("=== Response ===", ("HTTP %s"):format(tostring(r.response_code or "?")))

  if r.headers and vim.trim(r.headers) ~= "" then add("=== Response headers ===", vim.trim(r.headers)) end

  local body = r.body or ""
  if body:match("^No response body %(check Verbose output%)") then
    add("=== Response body ===", body)
  else
    add("=== Response body ===", pretty_maybe_json(body))
  end

  local st = format_stats(r.stats)
  if st ~= "" then add("=== Transfer stats ===", st) end

  local script_chunks = {}
  if r.script_pre_output and vim.trim(r.script_pre_output) ~= "" then
    table.insert(script_chunks, "--- Pre-request script ---")
    table.insert(script_chunks, r.script_pre_output)
  end
  if r.script_post_output and vim.trim(r.script_post_output) ~= "" then
    table.insert(script_chunks, "--- Post-request script ---")
    table.insert(script_chunks, r.script_post_output)
  end
  if #script_chunks > 0 then add("=== Script output ===", table.concat(script_chunks, "\n")) end

  return vim.trim(table.concat(parts, "\n"))
end

return M
