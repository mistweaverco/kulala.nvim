local M = {}

M.git = function(cwd, args, on_exit)
  vim.system(vim.list_extend({ "git" }, args), { cwd = cwd }, function(res)
    vim.schedule(function()
      on_exit(res)
    end)
  end)
end

return M
