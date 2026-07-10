vim.keymap.set("n", "<leader><Tab>", "<C-w>w", { noremap = true, silent = true, desc = "Next window" })

vim.keymap.set("n", "<C-Right>", "<C-w>>", { noremap = true, silent = true, desc = "Resize split right" })
vim.keymap.set("n", "<C-Left>", "<C-w><", { noremap = true, silent = true, desc = "Resize split left" })
vim.keymap.set("n", "<C-Up>", "<C-w>+", { noremap = true, silent = true, desc = "Resize split up" })
vim.keymap.set("n", "<C-Down>", "<C-w>-", { noremap = true, silent = true, desc = "Resize split down" })
