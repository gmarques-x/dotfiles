-- Loaded on the VeryLazy event. LazyVim's own autocmds:
-- https://www.lazyvim.org/configuration/autocmds

-- `theme` sends SIGUSR1 to every running Neovim after a switch.
vim.api.nvim_create_autocmd("Signal", {
  pattern = "SIGUSR1",
  callback = function() vim.schedule(require("config.theme").apply) end,
})
