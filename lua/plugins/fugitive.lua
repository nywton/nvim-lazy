return {
	"tpope/vim-fugitive",
	cmd = { "Git", "Gvdiffsplit" }, -- Lazy-load only when running these commands
	init = function()
		-- In the Fugitive status buffer, make <CR> open the file in a split
		-- and maximize it, so code takes the major part of the screen
		-- (the status list stays as a thin strip; <C-w>w to jump back).
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "fugitive",
			callback = function()
				vim.keymap.set("n", "<CR>", "o<C-w>_", {
					buffer = true,
					remap = true,
					silent = true,
					desc = "Open file in maximized split",
				})
			end,
		})
	end,
	keys = {
		-- Git main
		{ "<leader>gg", "<cmd>0Git<CR>", desc = "Open Fugitive status (review hub)" },
		-- { "<leader>gg", "<cmd>tab Git<CR>", desc = "Open Fugitive in new tab (fullscreen)" },

		-- Review: side-by-side diff (VSCode-like), working tree vs index/HEAD
		{ "<leader>gv", "<cmd>Gvdiffsplit<CR>", desc = "Side-by-side diff of current file" },

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
