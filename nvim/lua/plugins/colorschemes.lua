-- Every colourscheme `theme` can pick (themes/*.sh), installed up front and
-- loaded only when chosen. LazyVim already brings tokyonight and catppuccin.
return {
  { "sainnhe/everforest", lazy = true },
  { "morhetz/gruvbox", lazy = true },
  { "nordtheme/vim", name = "nord", lazy = true },
  { "rose-pine/neovim", name = "rose-pine", lazy = true },
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  { "folke/tokyonight.nvim", lazy = true },

  -- LazyVim sets the colourscheme through this function, so `theme` decides.
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = function() require("config.theme").apply() end },
  },
}
