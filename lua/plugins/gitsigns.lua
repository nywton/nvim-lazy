return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" }, -- lazy-load on buffer open
	opts = {
		signs = {
			add = { text = "+" },
			change = { text = "~" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
		},
		numhl = false,
		linehl = false,
		watch_gitdir = {
			interval = 1000,
			follow_files = true,
		},
		current_line_blame = false,
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- "eol" | "overlay" | "right_align"
			delay = 1000,
		},
		sign_priority = 6,
		update_debounce = 100,
		status_formatter = nil, -- Use default
	},
	keys = {
		{ "<leader>hs", ":Gitsigns stage_hunk<CR>", desc = "Stage hunk", mode = "n" },
		{ "<leader>hr", ":Gitsigns reset_hunk<CR>", desc = "Reset hunk", mode = "n" },
		{ "<leader>hS", ":Gitsigns stage_buffer<CR>", desc = "Stage buffer", mode = "n" },
		{ "<leader>hu", ":Gitsigns undo_stage_hunk<CR>", desc = "Undo stage hunk", mode = "n" },
		{ "<leader>hR", ":Gitsigns reset_buffer<CR>", desc = "Reset buffer", mode = "n" },
		{ "<leader>hp", ":Gitsigns preview_hunk<CR>", desc = "Preview hunk", mode = "n" },
		{ "<leader>hb", ":Gitsigns blame_line<CR>", desc = "Blame line", mode = "n" },
		{ "<leader>tb", ":Gitsigns toggle_current_line_blame<CR>", desc = "Toggle blame", mode = "n" },
		{ "<leader>hd", ":Gitsigns diffthis<CR>", desc = "Diff this buffer", mode = "n" },
		{ "<leader>hD", ":Gitsigns diffthis ~<CR>", desc = "Diff against last commit", mode = "n" },
		{ "<leader>td", ":Gitsigns toggle_deleted<CR>", desc = "Toggle deleted", mode = "n" },
	},
	config = function(_, opts)
		require("gitsigns").setup(opts)
	end,
}
