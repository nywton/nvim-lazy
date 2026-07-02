return {
	"sindrets/diffview.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
	keys = {
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history (diffview)" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<CR>",  desc = "Repo history (diffview)" },
		-- Morning review: see everything that changed in the last pull
		-- DiffviewOpen  → file panel (all changed files) + hunk diff, Tab/S-Tab walks files
		-- DiffviewFileHistory → commit list, Tab/S-Tab walks commits one by one
		{
			"<leader>go",
			function()
				local has_orig = vim.fn.system("git rev-parse --verify ORIG_HEAD 2>/dev/null"):match("%S")
				if has_orig then
					vim.cmd("DiffviewOpen ORIG_HEAD")
				else
					local upstream = vim.trim(vim.fn.system("git rev-parse --abbrev-ref '@{u}' 2>/dev/null"))
					local ref = (vim.v.shell_error == 0 and upstream ~= "") and upstream or "origin/main"
					vim.cmd("DiffviewOpen " .. ref)
				end
			end,
			desc = "Review last pull — all changed files + hunks",
		},
		{
			"<leader>gO",
			function()
				local has_orig = vim.fn.system("git rev-parse --verify ORIG_HEAD 2>/dev/null"):match("%S")
				if has_orig then
					vim.cmd("DiffviewFileHistory --range=ORIG_HEAD..HEAD")
				else
					local upstream = vim.trim(vim.fn.system("git rev-parse --abbrev-ref '@{u}' 2>/dev/null"))
					local ref = (vim.v.shell_error == 0 and upstream ~= "") and upstream or "origin/main"
					vim.cmd("DiffviewFileHistory --range=" .. ref .. "..HEAD")
				end
			end,
			desc = "Review last pull — commit by commit (Tab to advance)",
		},
	},
	opts = {
		view = {
			file_history = {
				layout = "diff2_horizontal",
			},
		},
	},
}
