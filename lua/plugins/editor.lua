return {
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("nvim-autopairs").setup({
				disable_filetype = { "TelescopePrompt", "vim" },
				-- <CR> is owned by the completion mapping in lua/config/lsp.lua,
				-- which calls autopairs_cr() itself when no completion is selected.
				map_cr = false,
			})
		end,
	},
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		opts = {
			-- Single source of truth for format-on-save. Filetypes without a
			-- formatter listed here fall back to the language server.
			-- All formatters below are Node-free external binaries (stylua), a gem
			-- (rubocop) or a Python package (black). JS/TS/JSON/CSS have no Node-free
			-- formatter, so they are normalized dependency-free via Treesitter
			-- re-indent in lua/config/tsformat.lua instead of being listed here.
			formatters_by_ft = {
				lua = { "stylua" },
				ruby = { "rubocop" },
				python = { "black" },
			},
			-- Filetypes normalized dependency-free in lua/config/tsformat.lua (Treesitter
			-- re-indent) are skipped here so the two don't both run on save.
			format_on_save = function(bufnr)
				if require("config.tsformat").filetypes[vim.bo[bufnr].filetype] then
					return
				end
				return { timeout_ms = 1000, lsp_format = "fallback" }
			end,
		},
	},
}
