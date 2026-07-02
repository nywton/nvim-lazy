return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
	keys = {
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history (diffview)" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<CR>", desc = "Repo history (diffview)" },
	},
	opts = {
		view = {
			file_history = {
				layout = "diff2_horizontal",
			},
		},
	},
}
