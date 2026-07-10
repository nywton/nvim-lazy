-- Movement, search, jumps, quickfix/loclist — centered-cursor behavior.

vim.keymap.set("n", "<Up>", "<Nop>", { desc = "Disable Up arrow" })
vim.keymap.set("n", "<Right>", "<Nop>", { desc = "Disable Right arrow" })
vim.keymap.set("n", "<Down>", "<Nop>", { desc = "Disable Down arrow" })
vim.keymap.set("n", "<Left>", "<Nop>", { desc = "Disable Left arrow" })

vim.keymap.set("n", "<C-o>", "<C-o>zz", { desc = "Jump back and center" })
vim.keymap.set("n", "<C-i>", "<C-i>zz", { desc = "Jump forward and center" })

vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Page down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Page up and center" })

vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result centered" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result centered" })

vim.keymap.set("n", "G", "m`Gzz", { desc = "Go to end of file centered" })

vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz", { desc = "Next quickfix item" })
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz", { desc = "Previous quickfix item" })
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Next location list item" })
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Previous location list item" })

-- Ported as-is from the old config; flagged in the tutorial as worth
-- reconsidering (centers on *every* line move, not just jumps/searches).
-- Comment out these two if `3j`/`dj` start to feel laggy.
vim.keymap.set("n", "j", "jzz", { desc = "Move down and center" })
vim.keymap.set("n", "k", "kzz", { desc = "Move up and center" })

vim.keymap.set("n", "#", "#zz", { desc = "Search backward and center" })
vim.keymap.set("n", "*", "*zz", { desc = "Search forward and center" })

-- Bare ripgrep+fzf code navigation. No LSP, no ctags: rg searches, fzf
-- picks. With no server to disambiguate "definition" from "implementation"
-- from "references", all three just jump to a picked occurrence of the
-- word under the cursor.
vim.keymap.set("n", "gd", function()
  require("finder.grep").goto_word()
end, { desc = "Go to definition (rg+fzf)" })
vim.keymap.set("n", "gi", function()
  require("finder.grep").goto_word()
end, { desc = "Go to implementation (rg+fzf)" })
vim.keymap.set("n", "gr", function()
  require("finder.grep").goto_word()
end, { desc = "Find references (rg+fzf)" })
