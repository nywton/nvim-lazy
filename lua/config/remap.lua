-- Leader key
vim.g.mapleader = " "

-- Command-line shortcut: ';' → ':'
vim.keymap.set('n', ';', ':', { noremap = true, desc = "Command-line mode" })

-- Reload Neovim config
vim.keymap.set('n', '<Leader>rl', ':source $MYVIMRC<CR>', { desc = "Reload config", silent = false })

-- Auto-indent entire file without moving cursor
vim.keymap.set('n', '<leader>i', function()
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd('normal! gg=G')
  vim.api.nvim_win_set_cursor(0, pos)
end, { desc = "Auto-indent whole file", silent = true })

-- Copy current file absolute path to clipboard
vim.keymap.set('n', '<leader>cp', function()
  vim.fn.setreg('+', vim.fn.expand('%:p'))
end, { desc = "Copy absolute file path" })


-- Toggle NvimTree file explorer
-- vim.keymap.set("n", "<leader>e", function() vim.cmd("Ex") end, { desc = "Open Ex in current directory" })
vim.keymap.set("n", "<leader>e", function() vim.cmd("Ex " .. vim.fn.expand("%:p:h")) end, { desc = "Open Ex in current file's directory" })


-- Save current file forcibly
vim.keymap.set("n", "<leader>w", "<cmd>:w!<CR>", { desc = "Save file" })

-- Quit current window forcibly
vim.keymap.set("n", "<leader>q", "<cmd>:q!<CR>", { desc = "Quit window" })

-- Visual block mode (column selection)
vim.keymap.set('n', '<leader>v', '<C-v>', { noremap = true, silent = true, desc = "Visual block mode" })

-- Change directory and open remap file
vim.keymap.set('n', '<leader>rm', ':cd ~/.config/nvim | edit lua/kyoris/remap.lua<CR>', {
  noremap = true,
  silent = true,
  desc = "Open remap.lua in config"
})

-- Disable arrow keys in normal mode (encourage hjkl)
vim.keymap.set("n", "<Up>", "<Nop>", { desc = "Disable Up arrow" })
vim.keymap.set("n", "<Right>", "<Nop>", { desc = "Disable Right arrow" })
vim.keymap.set("n", "<Down>", "<Nop>", { desc = "Disable Down arrow" })
vim.keymap.set("n", "<Left>", "<Nop>", { desc = "Disable Left arrow" })

-- Center cursor after jump back/forward
vim.keymap.set("n", "<C-o>", "<C-o>zz", { desc = "Jump back and center" })
vim.keymap.set("n", "<C-i>", "<C-i>zz", { desc = "Jump forward and center" })

-- Move selected lines up/down in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '>-2<CR>gv=gv", { desc = "Move selection up" })

-- Join lines and keep cursor centered
vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines with cursor fix" })

-- Scroll half-pages and center cursor
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Page down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Page up and center" })

-- Search next/prev results and center cursor
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result centered" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result centered" })

-- Go to end of file and center cursor
vim.keymap.set("n", "G", "m`Gzz", { desc = "Go to end of file centered" })

-- Paste over selection without affecting clipboard
vim.keymap.set("x", "<leader>p", "\"_dP", { desc = "Paste without replacing clipboard" })

-- Yank to system clipboard
vim.keymap.set("n", "<leader>y", "\"+y", { desc = "Yank to system clipboard" })
vim.keymap.set("v", "<leader>y", "\"+y", { desc = "Yank selection to system clipboard" })
vim.keymap.set("n", "<leader>Y", "\"+Y", { desc = "Yank line to system clipboard" })

-- Delete without affecting clipboard
vim.keymap.set("n", "<leader>d", "\"_d", { desc = "Delete without yank" })
vim.keymap.set("v", "<leader>d", "\"_d", { desc = "Delete selection without yank" })

-- Format buffer with LSP
vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, { desc = "Format buffer with LSP" })

-- Quickfix and location list navigation, centered
vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz", { desc = "Next quickfix item" })
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz", { desc = "Previous quickfix item" })
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Next location list item" })
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Previous location list item" })

-- Center cursor when moving up/down/searching
vim.keymap.set("n", "j", "jzz", { desc = "Move down and center" })
vim.keymap.set("n", "k", "kzz", { desc = "Move up and center" })
vim.keymap.set("n", "#", "#zz", { desc = "Search backward and center" })
vim.keymap.set("n", "*", "*zz", { desc = "Search forward and center" })

-- Exit insert mode with 'jj'
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })

-- Replace word under cursor throughout file (interactive)
vim.keymap.set("n", "<leader>r", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  { desc = "Replace word under cursor" })

-- Open packer config
vim.keymap.set("n", "<leader>vpp", "<cmd>e ~/.config/nvim/lua/kyoris/packer.lua<CR>", { desc = "Edit packer.lua" })

-- Open remap config
vim.keymap.set("n", "<leader>km", "<cmd>e ~/.config/nvim/lua/kyoris/remap.lua<CR>", { desc = "Edit remap.lua" })

-- Switch to next split window
vim.keymap.set('n', '<leader><Tab>', '<C-w>w', { noremap = true, silent = true, desc = "Next window" })

-- Resize splits with Ctrl + arrows
vim.keymap.set('n', '<C-Right>', '<C-w>>', { noremap = true, silent = true, desc = "Resize split right" })
vim.keymap.set('n', '<C-Left>', '<C-w><', { noremap = true, silent = true, desc = "Resize split left" })
vim.keymap.set('n', '<C-Up>', '<C-w>+', { noremap = true, silent = true, desc = "Resize split up" })
vim.keymap.set('n', '<C-Down>', '<C-w>-', { noremap = true, silent = true, desc = "Resize split down" })

-- Mix format current file (Elixir)
vim.keymap.set("n", "<leader>mf", "<cmd>silent! !mix format %<CR>", { desc = "Mix format current file" })

-- Auto format on save for Elixir files
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*.ex", "*.exs", "*.heex" },
  command = "silent! !mix format %",
})

-- Cross-platform file path copying
if vim.loop.os_uname().sysname == "Windows_NT" then
  -- Relative path with backslashes (Windows)
  vim.keymap.set("n", "<leader>cs", function()
    vim.fn.setreg("+", vim.fn.expand("%"):gsub("/", "\\"))
  end, { desc = "Copy relative path (Windows)" })

  -- Absolute path with backslashes (Windows)
  vim.keymap.set("n", "<leader>cl", function()
    vim.fn.setreg("+", vim.fn.expand("%:p"):gsub("/", "\\"))
  end, { desc = "Copy absolute path (Windows)" })

  -- 8.3 DOS path format (Windows)
  vim.keymap.set("n", "<leader>c8", function()
    vim.fn.setreg("+", vim.fn.expand("%:p:8"):gsub("/", "\\"))
  end, { desc = "Copy 8.3 DOS path (Windows)" })
else
  -- Relative path (Unix/macOS)
  vim.keymap.set("n", "<leader>cs", function()
    vim.fn.setreg("+", vim.fn.expand("%"))
  end, { desc = "Copy relative path" })

  -- Absolute path (Unix/macOS)
  vim.keymap.set("n", "<leader>cl", function()
    vim.fn.setreg("+", vim.fn.expand("%:p"))
  end, { desc = "Copy absolute path" })
end
