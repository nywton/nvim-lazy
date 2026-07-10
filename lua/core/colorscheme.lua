vim.o.cursorline = true
vim.cmd.colorscheme("habamax")

-- lua/git/signs.lua's bare sign-column implementation reads these highlight
-- groups. DiffAdd/DiffChange/DiffDelete are core groups every colorscheme
-- defines, so this stays in sync regardless of which one is active.
vim.api.nvim_set_hl(0, "GitSignsAdd", { link = "DiffAdd" })
vim.api.nvim_set_hl(0, "GitSignsChange", { link = "DiffChange" })
vim.api.nvim_set_hl(0, "GitSignsDelete", { link = "DiffDelete" })
