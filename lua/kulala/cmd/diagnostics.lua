local M = {}

local ts = vim.treesitter

local function kulala_diag_ns()
  return vim.api.nvim_create_namespace("kulala_diagnostics")
end

local function get_diagnostics(bufnr, parser)
  local diagnostics = {}

  parser = parser or ts.get_parser(bufnr, "kulala_http")
  if not parser then return diagnostics end

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
        severity = 1, -- Error severity in LSP
        source = "kulala",
        message = "Parsing error" .. (parent_type and " in " .. parent_type or ""),
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
  local parser = ts.get_parser(bufnr, "kulala_http")
  local diags = get_diagnostics(bufnr, parser)
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

return M
