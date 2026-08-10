local CONFIG = require("kulala.config")

local M = {}

M.ns = vim.api.nvim_create_namespace("kulala_openapi_panel")

local METHOD_GROUPS = {
  GET = "KulalaOpenAPIMethodGet",
  POST = "KulalaOpenAPIMethodPost",
  PUT = "KulalaOpenAPIMethodPut",
  DELETE = "KulalaOpenAPIMethodDelete",
  PATCH = "KulalaOpenAPIMethodPatch",
  HEAD = "KulalaOpenAPIMethodHead",
  OPTIONS = "KulalaOpenAPIMethodOptions",
}

local KIND_GROUPS = {
  section = "KulalaOpenAPISection",
  operation = "KulalaOpenAPIOperation",
  parameter = "KulalaOpenAPIParameter",
  response = "KulalaOpenAPIResponse",
  schema = "KulalaOpenAPISchema",
  text = "KulalaOpenAPIText",
  tryItOut = "KulalaOpenAPITryItOut",
}

function M.setup()
  local hl = CONFIG.get().openapi_panel and CONFIG.get().openapi_panel.highlights or {}

  vim.api.nvim_set_hl(0, "KulalaOpenAPISection", { link = hl.section or "Title", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIOperation", { link = hl.operation or "Function", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIParameter", { link = hl.parameter or "Identifier", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIResponse", { link = hl.response or "Number", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPISchema", { link = hl.schema or "Type", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIText", { link = hl.text or hl.description or "Comment", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIDescription", { link = hl.description or "Comment", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPITryItOut", { link = hl.try_it_out or "String", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIBadge", { link = hl.badge or "Comment", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPISign", { link = hl.sign or "Special", default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIValue", { link = hl.value or "Constant", default = true })

  vim.api.nvim_set_hl(0, "KulalaOpenAPIMethodGet", { fg = hl.method_get or "#61affe", bold = true, default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIMethodPost", { fg = hl.method_post or "#49cc90", bold = true, default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIMethodPut", { fg = hl.method_put or "#fca130", bold = true, default = true })
  vim.api.nvim_set_hl(
    0,
    "KulalaOpenAPIMethodDelete",
    { fg = hl.method_delete or "#f93e3e", bold = true, default = true }
  )
  vim.api.nvim_set_hl(0, "KulalaOpenAPIMethodPatch", { fg = hl.method_patch or "#50e3c2", bold = true, default = true })
  vim.api.nvim_set_hl(0, "KulalaOpenAPIMethodHead", { fg = hl.method_head or "#9012fe", bold = true, default = true })
  vim.api.nvim_set_hl(
    0,
    "KulalaOpenAPIMethodOptions",
    { fg = hl.method_options or "#0d5aa7", bold = true, default = true }
  )
end

---@param line string
---@return string|nil method
---@return integer|nil method_start col0
---@return integer|nil method_end col0 exclusive
local function parse_method_span(line)
  local prefix, method = line:match("^(%s*[>v]%s+)(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)%s")
  if not method or not prefix then return nil end
  local start = #prefix
  return method, start, start + #method
end

---@param bufnr integer
---@param lines string[]
---@param line_map table[]
function M.apply(bufnr, lines, line_map)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
  local set_hl = vim.fn.has("nvim-0.11") == 1 and vim.hl.range or vim.highlight.range

  for row, node in ipairs(line_map) do
    local line = lines[row] or ""
    local row0 = row - 1
    local kind_hl = KIND_GROUPS[node.kind]
    if kind_hl then set_hl(bufnr, M.ns, kind_hl, { row0, 0 }, { row0, -1 }, { priority = 10 }) end

    if node.kind == "text" and node.parentId then
      set_hl(bufnr, M.ns, "KulalaOpenAPIDescription", { row0, 0 }, { row0, -1 }, { priority = 12 })
    else
      -- Only the fold marker after leading indent (`  v Title`), never letters inside descriptions.
      local indent, sign = line:match("^(%s*)([>v])%s")
      if indent and sign then
        local sign_start = #indent
        set_hl(bufnr, M.ns, "KulalaOpenAPISign", { row0, sign_start }, { row0, sign_start + 1 }, { priority = 20 })
      end
    end

    local badge_start = line:find("%[", 1, true)
    if badge_start and not (node.kind == "text" and node.parentId) then
      set_hl(bufnr, M.ns, "KulalaOpenAPIBadge", { row0, badge_start - 1 }, { row0, -1 }, { priority = 15 })
    end

    if node.kind == "operation" then
      local method, start, finish = parse_method_span(line)
      if method and start and finish then
        local group = METHOD_GROUPS[method] or "KulalaOpenAPIOperation"
        set_hl(bufnr, M.ns, group, { row0, start }, { row0, finish }, { priority = 25 })
      end
    end

    if node.kind == "tryItOut" then
      local eq = line:find(" = ", 1, true)
      if eq then set_hl(bufnr, M.ns, "KulalaOpenAPIValue", { row0, eq + 2 }, { row0, -1 }, { priority = 25 }) end
    end
  end
end

return M
