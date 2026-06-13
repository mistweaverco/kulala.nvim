---Markdown verbose view (curl `-v`-style detail, structured for readability).
local Json = require("kulala.utils.json")
local Markdown = require("kulala.ui.markdown")

local M = {}

---@param body table|nil
---@return string, string
local function format_hop_body(body)
  if type(body) ~= "table" then return "", "text" end
  if body.type == "json" and body.content ~= nil then
    local ok, s = pcall(vim.json.encode, body.content)
    if ok and s then return Markdown.pretty_maybe_json(s), "json" end
    return vim.inspect(body.content), "text"
  end
  if body.type == "text" and body.content then return Markdown.fenced("text", body.content), "text" end
  return "", "text"
end

---@param hop table
---@param index number
---@param title string
---@return string
local function format_hop(hop, index, title)
  if type(hop) ~= "table" then return "" end
  local parts = {}
  table.insert(
    parts,
    ("## %s %d — HTTP %s\n"):format(title, index, Markdown.md_escape_cell(tostring(hop.status or "?")))
  )
  if hop.url then table.insert(parts, ("**URL:** %s\n"):format(Markdown.md_escape_cell(hop.url))) end

  local tm = Markdown.format_timings(hop.timings)
  if tm ~= "" then
    table.insert(parts, "### Timings\n")
    table.insert(parts, tm)
  end

  if hop.headers then
    table.insert(parts, "### Response headers\n")
    table.insert(parts, Markdown.format_headers_table(hop.headers))
  end

  local body, lang = format_hop_body(hop.body)
  if body ~= "" then
    table.insert(parts, "### Response body\n")
    table.insert(parts, Markdown.fenced(lang, body))
  end

  local trace = Markdown.format_connection_trace(hop.verboseTrace)
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

---@param r Response
---@return string
function M.format(r)
  local parts = {}
  local method = r.method or "?"
  local url = (r.request and r.request.url) or r.url or "?"
  table.insert(parts, ("# %s %s\n"):format(Markdown.md_escape_cell(method), Markdown.md_escape_cell(url)))

  if r.errors and Markdown.trim(r.errors) ~= "" then
    Markdown.add_section(parts, "## Errors\n", Markdown.fenced("text", Markdown.trim(r.errors)))
  end

  table.insert(parts, "## Request\n")
  table.insert(
    parts,
    ("%s %s\n"):format(Markdown.md_escape_cell(method), Markdown.md_escape_cell((r.request and r.request.url) or url))
  )

  local req_headers = r.request and r.request.headers_tbl
  if req_headers and next(req_headers) then
    table.insert(parts, "### Request headers\n")
    table.insert(parts, Markdown.format_headers_table(req_headers))
  end

  local req_body = r.request and r.request.body
  if type(req_body) == "string" and Markdown.trim(req_body) ~= "" then
    table.insert(parts, "### Request body\n")
    local is_json = Json.parse(req_body, { verbose = false })
    local ft = is_json and "json" or "text"
    table.insert(parts, Markdown.fenced(ft, req_body, ft == "json"))
  end

  local chain = r._kulala_redirect_chain
  local intermediate = chain and redirect_chain_without_final(chain)
  if intermediate and #intermediate > 0 then
    table.insert(parts, "## Redirect chain\n")
    for i, hop in ipairs(intermediate) do
      table.insert(parts, format_hop(hop, i, "Hop"))
    end
  end

  table.insert(parts, ("## Response — HTTP %s\n"):format(Markdown.md_escape_cell(tostring(r.response_code or "?"))))

  local response_headers = Markdown.response_headers_source(r)
  if response_headers then
    table.insert(parts, "### Response headers\n")
    table.insert(parts, Markdown.format_headers_table(response_headers))
  end

  local body = r.body or ""
  if body:match("^No response body %(check Verbose output%)") then
    table.insert(parts, "### Response body\n")
    table.insert(parts, "_No response body_\n")
  else
    local content, lang = Markdown.get_body_and_guess_ft(r, body)
    table.insert(parts, "### Response body\n")
    table.insert(parts, Markdown.fenced(lang, content))
  end

  local trace = r._kulala_verbose_trace or r.verboseTrace
  local conn = Markdown.format_connection_trace(trace)
  if conn ~= "" then
    table.insert(parts, "## Connection trace\n")
    table.insert(parts, conn)
  end

  local st = Markdown.format_stats_table(r.stats)
  if st ~= "" then
    table.insert(parts, "## Transfer timings\n")
    table.insert(parts, st)
  end

  local script = Markdown.format_script_output(r)
  if script ~= "_No script output_\n" then Markdown.add_section(parts, "## Script output\n", script) end

  return Markdown.trim(table.concat(parts, "\n"))
end

-- Re-export shared view formatters for callers that still require verbose.
M.format_headers_view = Markdown.format_headers_view
M.format_body_view = Markdown.format_body_view
M.format_headers_body_view = Markdown.format_headers_body_view
M.format_script_output = Markdown.format_script_output

return M
