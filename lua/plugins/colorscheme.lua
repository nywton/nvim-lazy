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
      },
    })
    vim.o.cursorline = true
    vim.cmd.colorscheme("catppuccin")
  end,
}
