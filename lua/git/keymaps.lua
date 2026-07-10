local git = require("git.commands")
local hunks = require("git.hunks")

vim.keymap.set("n", "<leader>gg", git.status, { desc = "Git status" })
vim.keymap.set("n", "<leader>gd", function() git.diff() end, { desc = "Git diff" })
vim.keymap.set("n", "<leader>gb", git.blame, { desc = "Git blame" })
vim.keymap.set("n", "<leader>gl", git.log, { desc = "Git log" })

vim.keymap.set("n", "]c", hunks.next, { desc = "Next uncommitted hunk (repo-wide)" })
vim.keymap.set("n", "[c", hunks.prev, { desc = "Previous uncommitted hunk (repo-wide)" })

-- Merge conflicts — plain Vim diff-mode commands, no plugin involved.
vim.keymap.set("n", "<leader>g1", "<cmd>diffget //2<CR>", { desc = "Use our version (diffget //2)" })
vim.keymap.set("n", "<leader>g2", "<cmd>diffget //3<CR>", { desc = "Use their version (diffget //3)" })

-- Finder + quickset (harpoon replacement) — grouped here since <C-p>/<leader>s
-- aren't "editing" or "navigation" in the core sense, they're project tools.
vim.keymap.set("n", "<C-p>", function() require("finder.files").find_files() end, { desc = "Find files" })
vim.keymap.set("n", "<leader>s", function() require("finder.grep").live_grep() end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>b", function()
  local bufs = vim.tbl_filter(function(b)
    return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted
  end, vim.api.nvim_list_bufs())
  vim.ui.select(bufs, {
    format_item = function(b) return vim.fn.bufname(b) end,
  }, function(choice)
    if choice then vim.api.nvim_set_current_buf(choice) end
  end)
end, { desc = "Switch buffer" })

vim.keymap.set("n", "<leader>a", function() require("finder.quickset").add() end, { desc = "Quickset: add file" })
vim.keymap.set("n", "<C-e>", function() require("finder.quickset").menu() end, { desc = "Quickset: menu" })
vim.keymap.set("n", "<C-h>", function() require("finder.quickset").prev() end, { desc = "Quickset: previous" })
vim.keymap.set("n", "<C-t>", function() require("finder.quickset").next() end, { desc = "Quickset: next" })
