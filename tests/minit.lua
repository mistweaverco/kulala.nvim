#!/usr/bin/env -S nvim -l

vim.env.LAZY_STDPATH = ".tests"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

package.path = "./tests/?.lua;./tests/?/?.lua;" .. package.path
vim.opt.rtp:append(vim.uv.cwd())

_, _G.DevTools = pcall(require, "log")

-- Install JS scripts dependencies
require("kulala.parser.scripts.engines.javascript").install_dependencies(true)

require("lazy.minit").busted({
  headless = {
    process = false,
    log = false, -- show log messages
    task = false, -- show task start/end
    colors = true, -- use ansi colors
  },
  { dir = vim.uv.cwd() }, -- Current working directory for tests
  { "nvim-treesitter/nvim-treesitter" },
}, { install = { missing = true } })
