-- Text manipulation: indent, join/move lines, yank/delete/paste, replace.

vim.keymap.set("n", "<leader>i", function()
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd("normal! gg=G")
  vim.api.nvim_win_set_cursor(0, pos)
end, { desc = "Auto-indent whole file", silent = true })

vim.keymap.set("n", "<leader>v", "<C-v>", { noremap = true, silent = true, desc = "Visual block mode" })

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '>-2<CR>gv=gv", { desc = "Move selection up" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines with cursor fix" })

vim.keymap.set("x", "<leader>p", '"_dP', { desc = "Paste without replacing clipboard" })

vim.keymap.set("n", "<leader>y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Yank selection to system clipboard" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "Yank line to system clipboard" })

vim.keymap.set("n", "<leader>d", '"_d', { desc = "Delete without yank" })
vim.keymap.set("v", "<leader>d", '"_d', { desc = "Delete selection without yank" })

vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })

vim.keymap.set(
  "n",
  "<leader>r",
  [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  { desc = "Replace word under cursor" }
)
