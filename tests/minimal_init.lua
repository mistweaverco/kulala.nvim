local lazypath = vim.fn.stdpath("data") .. "/lazy"
vim.notify = print
vim.opt.rtp:append(".")
vim.opt.rtp:append(lazypath .. "/plenary.nvim")
vim.opt.swapfile = false
vim.cmd("runtime! plugin/plenary.vim")
A = function(...)
  print(vim.inspect(...))
end
