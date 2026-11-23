-- The colourscheme chosen with `theme`. lua/theme.lua is written by `theme`
-- (and not tracked by git); without it, Nord.
local M = {}

-- Keep the terminal's background (and its blur) behind every colourscheme.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("dotfiles_transparent", { clear = true }),
  callback = function()
    for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "SignColumn", "EndOfBuffer", "LineNr", "FoldColumn" }) do
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      hl.bg, hl.ctermbg = nil, nil
      vim.api.nvim_set_hl(0, group, hl)
    end
  end,
})

function M.apply()
  package.loaded.theme = nil
  local ok, t = pcall(require, "theme")
  if not ok then
    t = { background = "dark", colorscheme = "nord" }
  end
  vim.o.background = t.background
  if t.setup then
    t.setup()
  end
  -- lazy.nvim loads the colourscheme's plugin (lua/plugins/colorschemes.lua) on demand.
  if not pcall(vim.cmd.colorscheme, t.colorscheme) then
    vim.cmd.colorscheme("habamax")
  end
end

return M
