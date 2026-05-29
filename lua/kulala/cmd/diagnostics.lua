local M = {}

local Bridge = require("kulala.cmd.kulala_core_bridge")

local function kulala_diag_ns()
  return vim.api.nvim_create_namespace("kulala_diagnostics")
end

local pending = {} ---@type table<number, boolean>
local augroup = vim.api.nvim_create_augroup("KulalaDiagnostics", { clear = false })

local function apply_diagnostics(bufnr, core_diags)
  local severity_map = {
    [1] = vim.diagnostic.ERROR,
    [2] = vim.diagnostic.WARN,
    [3] = vim.diagnostic.INFO,
    [4] = vim.diagnostic.HINT,
  }

  local diags = {}
  for _, d in ipairs(core_diags or {}) do
    local r = d.range or {}
    local s = r.start or {}
    local e = r["end"] or {}
    table.insert(diags, {
      bufnr = bufnr,
      lnum = s.line or 0,
      col = s.character or 0,
      end_lnum = e.line or (s.line or 0),
      end_col = e.character or (s.character or 0),
      severity = severity_map[d.severity] or vim.diagnostic.ERROR,
      source = d.source or "kulala-core",
      message = d.message or "kulala-core diagnostic",
      type = "core",
    })
  end

  vim.diagnostic.set(kulala_diag_ns(), bufnr, diags, {})
end

local function update_diagnostics_async(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  if pending[bufnr] then return end
  pending[bufnr] = true

  -- debounce a bit to avoid spawning a subprocess on every keystroke
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      pending[bufnr] = false
      return
    end
    Bridge.lsp_diagnostics_async(bufnr, function(core_diags, _err)
      pending[bufnr] = false
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      if type(core_diags) ~= "table" then
        vim.diagnostic.set(kulala_diag_ns(), bufnr, {}, {})
        return
      end
      apply_diagnostics(bufnr, core_diags)
    end)
  end, 75)
end

function M.setup(bufnr)
  update_diagnostics_async(bufnr)

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      update_diagnostics_async(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup,
    buffer = bufnr,
    callback = function()
      pending[bufnr] = false
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
