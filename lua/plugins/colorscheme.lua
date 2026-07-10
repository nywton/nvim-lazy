-- Deliberately kept plugin (see tutorial Phase 3): no built-in colorscheme
-- reproduces this palette or its treesitter/git-aware highlight groups, and
-- a colorscheme has no keymaps/autocommands to fight the rest of the config.
return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      background = { light = "latte", dark = "mocha" },
      transparent_background = true,
      show_end_of_buffer = false,
      term_colors = false,
      integrations = {
        treesitter = true,
        -- gitsigns.nvim itself isn't installed — this only defines the
        -- GitSignsAdd/Change/Delete highlight groups, which lua/git/signs.lua
        -- (our bare sign-column implementation) reuses so colors stay in
        -- sync with the flavour/background without hardcoding hex here.
        gitsigns = true,
      },
    })
    vim.o.cursorline = true
    vim.cmd.colorscheme("catppuccin")
  end,
}
