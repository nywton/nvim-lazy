return {
	{
		"williamboman/mason.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
			"neovim/nvim-lspconfig",
		},
		config = function()
			-- Allow project-local config (.nvim.lua / .exrc), with the built-in trust prompt
			vim.o.exrc = true
			vim.g.ruby_host_prg = vim.fn.expand("~/.rbenv/shims/ruby")

			-- ===============================
			-- Diagnostics
			-- ===============================
			vim.diagnostic.config({
				virtual_text = { prefix = "●", source = "if_many", spacing = 2 },
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					border = "rounded",
					source = "if_many",
					focusable = false,
					scope = "line",
				},
			})

			vim.api.nvim_create_autocmd("CursorHold", {
				callback = function()
					local diags = vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
					if #diags > 0 then
						vim.diagnostic.open_float(nil, { focus = false })
					end
				end,
			})

			-- ===============================
			-- Capabilities (from blink.cmp when available)
			-- ===============================
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			local ok, blink = pcall(require, "blink.cmp")
			if ok then
				capabilities = blink.get_lsp_capabilities(capabilities)
			end
			vim.lsp.config("*", { capabilities = capabilities })

			-- ===============================
			-- Server-specific settings
			-- (filetypes, cmd and root markers come from nvim-lspconfig defaults)
			-- ===============================
			vim.lsp.config("ruby_lsp", {
				init_options = { formatter = "auto" },
			})

			vim.lsp.config("pyright", {
				settings = {
					python = {
						analysis = {
							typeCheckingMode = "basic",
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
						},
					},
				},
			})

			vim.lsp.config("tailwindcss", {
				filetypes = {
					"html",
					"css",
					"scss",
					"less",
					"javascript",
					"javascriptreact",
					"typescript",
					"typescriptreact",
					"vue",
					"svelte",
					"eruby",
				},
				settings = {
					tailwindCSS = {
						experimental = {
							classRegex = {
								'class\\s*=\\s*"([^"]+)"',
								':class\\s*=\\s*"([^"]+)"',
								':class\\s*=\\s*"[^"]*?([\'"][^\'"]+[\'"]).*"',
							},
						},
					},
				},
			})

			-- ===============================
			-- Mason + automatic server enable
			-- ===============================
			require("mason").setup()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"html",
					"cssls",
					"tailwindcss",
					"ruby_lsp",
					"ts_ls",
					"pyright",
				},
			})

			-- ===============================
			-- Keymaps (set when a server attaches)
			-- ===============================
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local map = function(mode, lhs, rhs, desc)
						vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
					end
					map("n", "gd", vim.lsp.buf.definition, "Go to definition")
					map("n", "gr", vim.lsp.buf.references, "References")
					map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
					map("n", "K", vim.lsp.buf.hover, "Hover docs")
					map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
					map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
					map("n", "<leader>cb", vim.lsp.buf.format, "Format buffer")
					map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, "Previous diagnostic")
					map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next diagnostic")
					map("n", "<leader>E", vim.diagnostic.open_float, "Line diagnostics")
					map("n", "<leader>Q", vim.diagnostic.setloclist, "Diagnostics to loclist")
				end,
			})
		end,
	},
}
