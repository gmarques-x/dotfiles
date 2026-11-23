-- Loaded before LazyVim's plugins. LazyVim's own defaults:
-- https://www.lazyvim.org/configuration/general
local o = vim.opt
o.relativenumber = true
o.expandtab, o.shiftwidth, o.tabstop = true, 2, 2
o.clipboard = "unnamedplus"   -- the macOS clipboard, also over SSH
o.swapfile = false
o.undofile = true
o.scrolloff = 5
o.signcolumn = "yes"
