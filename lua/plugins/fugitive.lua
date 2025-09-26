return {
	"tpope/vim-fugitive",
	cmd = { "Git", "Gvdiffsplit" }, -- Lazy-load only when running these commands
	keys = {
		-- Git main
		{ "<leader>gg", "<cmd>0Git<CR>", desc = "Open Fugitive in fullscreen buffer" },
		-- { "<leader>gg", "<cmd>tab Git<CR>", desc = "Open Fugitive in new tab (fullscreen)" },

		-- Git basic
		{ "<leader>gb", "<cmd>Git blame<CR>", desc = "Git blame" },
		{ "<leader>gl", "<cmd>Git log<CR>", desc = "Git log -p" },

		-- Git workflow
		-- { "<leader>gs", "<cmd>Git status<CR>", desc = "Git status" },
		{
			"<leader>gP",
			function()
				local branch = vim.fn.FugitiveHead()
				vim.cmd("Git push origin " .. branch)
			end,
			desc = "git push origin current-branch",
		},
		{
			"<leader>gp",
			function()
				local branch = vim.fn.FugitiveHead()
				vim.cmd("Git pull origin " .. branch)
			end,
			desc = "git pull origin current-branch",
		},
		{ "<leader>gc", "<cmd>Git commit<CR>", desc = "Git commit" },
		{ "<leader>gC", "<cmd>Git commit --amend<CR>", desc = "Amend last commit" },
		{ "<leader>ga", "<cmd>Git add %<CR>", desc = "Git add current file" },
		{ "<leader>gu", "<cmd>Git restore %<CR>", desc = "Discard changes in current file" },
		{ "<leader>gU", "<cmd>Git reset HEAD %<CR>", desc = "Unstage current file" },
		{ "<leader>gF", "<cmd>Git fetch<CR>", desc = "Git fetch" },

		-- Merge conflicts
		{ "<leader>g1", "<cmd>diffget //2<CR>", desc = "Use our version (diffget //2)" },
		{ "<leader>g2", "<cmd>diffget //3<CR>", desc = "Use their version (diffget //3)" },
		{ "<leader>gr", "<cmd>Git mergetool<CR>", desc = "Run Git mergetool" },
		{ "<leader>gD", "<cmd>Gvdiffsplit!<CR>", desc = "Vertical diff of conflicts" },

		-- Buffer nav (optional, not strictly git-related)
		{ "<leader>bn", "<cmd>bnext<CR>", desc = "Next buffer" },
		{ "<leader>bv", "<cmd>bprevious<CR>", desc = "Previous buffer" },
		{ "<leader>bd", "<cmd>bdelete<CR>", desc = "Delete buffer" },
	},
}
