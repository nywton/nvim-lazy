-- Meta / editor-level: save, quit, reload, explorer toggle, path copying.

vim.keymap.set("n", ";", ":", { noremap = true, desc = "Command-line mode" })

vim.keymap.set("n", "<Leader>rl", ":source $MYVIMRC<CR>", { desc = "Reload config", silent = false })

vim.keymap.set("n", "<leader>w", "<cmd>:w!<CR>", { desc = "Save file" })
vim.keymap.set("n", "<leader>q", "<cmd>:q!<CR>", { desc = "Quit window" })

vim.keymap.set("n", "<leader>e", function()
  if vim.bo.filetype == "netrw" then
    vim.cmd("b#")
  else
    vim.cmd("Ex " .. vim.fn.expand("%:p:h"))
  end
end, { desc = "Toggle Ex in current file's directory" })

-- NOTE: this replaces both old <leader>rm and <leader>km (they opened the
-- same file two different ways — collapsed to one chord).
vim.keymap.set("n", "<leader>ve", "<cmd>e ~/.config/nvim2/lua/core/keymaps/editing.lua<CR>",
  { desc = "Edit editing.lua keymaps" })

vim.keymap.set("n", "<leader>cp", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy absolute file path" })

if vim.loop.os_uname().sysname == "Windows_NT" then
  vim.keymap.set("n", "<leader>cs", function()
    vim.fn.setreg("+", vim.fn.expand("%"):gsub("/", "\\"))
  end, { desc = "Copy relative path (Windows)" })

  vim.keymap.set("n", "<leader>cl", function()
    vim.fn.setreg("+", vim.fn.expand("%:p"):gsub("/", "\\"))
  end, { desc = "Copy absolute path (Windows)" })

  vim.keymap.set("n", "<leader>c8", function()
    vim.fn.setreg("+", vim.fn.expand("%:p:8"):gsub("/", "\\"))
  end, { desc = "Copy 8.3 DOS path (Windows)" })
else
  vim.keymap.set("n", "<leader>cs", function()
    vim.fn.setreg("+", vim.fn.expand("%"))
  end, { desc = "Copy relative path" })

  vim.keymap.set("n", "<leader>cl", function()
    vim.fn.setreg("+", vim.fn.expand("%:p"))
  end, { desc = "Copy absolute path" })
end
