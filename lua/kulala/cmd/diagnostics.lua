local M = {}

local ts = vim.treesitter

local function kulala_diag_ns()
  return vim.api.nvim_create_namespace("kulala_diagnostics")
end

local function get_diagnostics(bufnr, parser)
  local diagnostics = {}
  local ok

  ok, parser = pcall(function()
    return parser or ts.get_parser(bufnr, "kulala_http")
  end)
  if not ok or not parser then return diagnostics end

  local tree = parser:parse()[1]
  local root = tree:root()

  local function find_errors(node, parent_type)
    if not node then return end

    local node_type = node:type()

    if node_type == "ERROR" then
      local lnum, col, end_lnum, end_col = node:range()

      table.insert(diagnostics, {
        bufnr = bufnr,
        lnum = lnum,
        end_lnum = end_lnum,
        col = col,
        end_col = end_col,
        severity = vim.diagnostic.ERROR,
        source = "kulala",
        message = "Parsing error" .. (parent_type and " in " .. parent_type or ""),
        type = "treesitter",
      })
    end

    for child in node:iter_children() do
      find_errors(child, node_type)
    end
  end

  find_errors(root)
  return diagnostics
end

local function update_diagnostics(bufnr)
  local ok, parser = pcall(ts.get_parser, bufnr, "kulala_http")
  if not ok then parser = nil end

  local existing_diags = vim.diagnostic.get(bufnr) or {}
  local parser_diags = vim
    .iter(existing_diags)
    :filter(function(diag)
      return diag.type == "parser"
    end)
    :totable()

  local diags = vim.list_extend(get_diagnostics(bufnr, parser), parser_diags)
  vim.diagnostic.set(kulala_diag_ns(), bufnr, diags, {})
end

function M.setup(bufnr)
  update_diagnostics(bufnr)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = vim.api.nvim_create_augroup("KulalaDiagnostics", { clear = true }),
    buffer = bufnr,
    callback = function()
      update_diagnostics(bufnr)
    end,
  })
end

M.add_diagnostics = function(bufnr, message, severity, ls, cs, le, ce)
  local diags = vim.diagnostic.get(bufnr)
  ls = math.max(0, ls or 0)
  le = math.max(0, le or ls or 0)

  if vim.iter(diags):find(function(diag)
    return diag.message == message and diag.lnum == ls
  end) then return end

  table.insert(diags, {
    bufnr = bufnr,
    lnum = ls,
    end_lnum = le,
    col = cs or 0,
    end_col = ce or cs or 0,
    severity = severity or vim.diagnostic.ERROR,
    source = "kulala",
    message = message,
    type = "parser",
  })

  vim.diagnostic.set(kulala_diag_ns(), bufnr, diags, {})
end

M.clear_diagnostics = function(bufnr, type)
  local diags = not type and {}
    or vim
      .iter(vim.diagnostic.get(bufnr))
      :filter(function(diag)
        return diag.type ~= type
      end)
      :totable()

  vim.diagnostic.set(kulala_diag_ns(), bufnr, diags, {})
end

return M
