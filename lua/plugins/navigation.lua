return {
	{
		"nvim-telescope/telescope.nvim",
		-- `master` (not the frozen 0.1.x) is needed for Neovim 0.12 +
		-- nvim-treesitter `main`: the previewer now uses vim.treesitter
		-- (get_lang/start) instead of the removed ft_to_lang.
		branch = "master",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = "Telescope", -- load only when :Telescope is called
		keys = {
			{ "<C-f>", "<cmd>Telescope git_files<CR>", desc = "Git files" },
			{
				"<C-p>",
				function()
					local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
					if vim.v.shell_error ~= 0 then
						root = vim.fn.getcwd()
					end
					require("telescope.builtin").find_files({ cwd = root })
				end,
				desc = "Search all files from project root",
			},
			{ "<leader>t", "<cmd>Telescope keymaps<CR>", desc = "Search all keymaps" },
			{ "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Git status" },
			{ "<leader>h", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
			{ "<leader>s", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
			{ "<leader>b", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
		},
		opts = {
			defaults = {
				layout_config = {
					width = 0.95,
					height = 0.95,
					preview_width = 0.55,
				},
			},
		},
	},
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local harpoon = require("harpoon")
			local list = harpoon:list()

			vim.keymap.set("n", "<leader>a", function()
				list:add()
			end, { desc = "Harpoon add file" })

			vim.keymap.set("n", "<C-e>", function()
				harpoon.ui:toggle_quick_menu(list)
			end, { desc = "Harpoon quick menu" })

			vim.keymap.set("n", "<C-h>", function()
				list:next()
			end, { desc = "Harpoon next file" })

			vim.keymap.set("n", "<C-t>", function()
				list:prev()
			end, { desc = "Harpoon prev file" })
		end,
	},
}
