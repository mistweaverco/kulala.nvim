#!/usr/bin/env -S nvim -l

vim.env.LAZY_STDPATH = ".tests"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

package.path = "./tests/?.lua;./tests/?/?.lua;" .. package.path
vim.opt.rtp:append(vim.uv.cwd())

_, _G.DevTools = pcall(require, "log")

-- Install JS scripts dependencies
require("kulala.parser.scripts.engines.javascript").install_dependencies(true)
-- require("kulala.cmd.fmt").check_formatter(nil, true)

-- Setup lazy.nvim
require("lazy.minit").busted({
  headless = {
    process = false,
    -- show log messages
    log = false,
    -- show task start/end
    task = false,
    -- use ansi colors
    colors = true,
  },
  spec = {
    { dir = vim.uv.cwd() },
  },
})
