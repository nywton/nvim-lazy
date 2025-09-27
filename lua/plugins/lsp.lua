return {
	-- Mason + LSP
	{
		"williamboman/mason.nvim",
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
			"neovim/nvim-lspconfig",
			"hrsh7th/cmp-nvim-lsp",
			"mfussenegger/nvim-jdtls",
		},
		config = function()
			local mason = require("mason")
			local mason_lspconfig = require("mason-lspconfig")
			local util = require("lspconfig.util")

			-- ===============================
			-- Local project-specific configs
			-- ===============================
			vim.o.exrc = true
			vim.g.ruby_host_prg = "/Users/nywton/.rbenv/shims/ruby"
			-- vim.o.secure = true

			-- ===============================
			-- Diagnostics
			-- ===============================
			vim.o.updatetime = 250
			vim.diagnostic.config({
				virtual_text = {
					prefix = "●",
					source = "if_many",
					spacing = 2,
				},
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
				float = {
					border = "rounded",
					source = "always",
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
			-- Mason setup
			-- ===============================
			mason.setup()
			mason_lspconfig.setup({
				ensure_installed = {
					"html",
					"cssls",
					"tailwindcss",
					"ruby_lsp",
					"ts_ls",
					"jdtls",
				},
			})

			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			local on_attach = function(client, bufnr)
				-- format on save
				if client.server_capabilities.documentFormattingProvider then
					vim.api.nvim_create_autocmd("BufWritePre", {
						group = vim.api.nvim_create_augroup("Format" .. bufnr, { clear = true }),
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format()
						end,
					})
				end
			end

			-- ===============================
			-- Java (using nvim-jdtls)
			-- ===============================
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "java" },
				callback = function()
					local jdtls = require("jdtls")
					local root_dir = util.root_pattern("gradlew", "mvnw", ".git")(vim.fn.getcwd())
					local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
					local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

					jdtls.start_or_attach({
						cmd = { "jdtls" }, -- mason installs this
						root_dir = root_dir,
						capabilities = capabilities,
						on_attach = on_attach,
						settings = { java = {} },
						init_options = { bundles = {} },
						workspaceFolders = { workspace_dir },
					})
				end,
			})

			-- ===============================
			-- TypeScript/JavaScript (ts_ls)
			-- ===============================
			vim.lsp.config.ts_ls = {
				on_attach = on_attach,
				capabilities = capabilities,
				root_dir = function(fname)
					return util.root_pattern("package.json", "tsconfig.json", "jsconfig.json", ".git")(fname)
				end,
			}

			-- ===============================
			-- Servers with new vim.lsp.config API
			-- ===============================

			-- HTML
			vim.lsp.config.html = {
				capabilities = capabilities,
				on_attach = on_attach,
				filetypes = { "html" },
			}

			-- CSS
			vim.lsp.config.cssls = {
				capabilities = capabilities,
				on_attach = on_attach,
				filetypes = { "css", "scss", "less" },
			}

			-- Tailwind LS (“tl_ls”), with support
			vim.lsp.config.tailwindcss = {
				capabilities = capabilities,
				on_attach = on_attach,
				filetypes = {
					"html",
					"javascript",
					"javascriptreact",
					"typescript",
					"typescriptreact",
					"vue",
					"svelte",
					"css",
					"scss",
					"less",
					"heex",
					"eelixir",
					"eruby",
					"templ",
				},
				settings = {
					tailwindCSS = {
						experimental = {
							classRegex = {
								-- class="..."
								'class\\s*=\\s*"([^"]+)"',
								-- :class="'px-4 py-2'"
								':class\\s*=\\s*"([^"]+)"',
								-- :class="[ 'p-2','m-2']" or :class="{ 'p-2': cond }"
								':class\\s*=\\s*"[^"]*?([\'"][^\'"]+[\'"]).*"',
							},
						},
					},
				},
			}

			-- Ruby
			vim.lsp.config.ruby_lsp = {
				capabilities = capabilities,
				on_attach = on_attach,
				filetypes = { "ruby" },
				init_options = { formatter = "auto" },
				settings = {
					rubocop = {
						command = "bundle",
						args = {
							"exec",
							"rubocop",
							"--config",
							vim.fn.getcwd() .. "/.rubocop.yml",
							"--format",
							"json",
						},
					},
				},
			}

			-- ===============================
			-- Autostart servers on filetypes
			-- ===============================

			-- TS/JS start ts_ls
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "typescript", "javascript", "javascriptreact", "typescriptreact" },
				callback = function(args)
					vim.lsp.start(vim.lsp.config.ts_ls, { bufnr = args.buf })
				end,
			})

			-- HTML start html + tailwindcss
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "html" },
				callback = function(args)
					vim.lsp.start(vim.lsp.config.html, { bufnr = args.buf })
					vim.lsp.start(vim.lsp.config.tailwindcss, { bufnr = args.buf })
				end,
			})

			-- CSS/SCSS/LESS
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "css", "scss", "less" },
				callback = function(args)
					vim.lsp.start(vim.lsp.config.cssls, { bufnr = args.buf })
					vim.lsp.start(vim.lsp.config.tailwindcss, { bufnr = args.buf })
				end,
			})

			-- Ruby
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "ruby" },
				callback = function(args)
					vim.lsp.start(vim.lsp.config.ruby_lsp, { bufnr = args.buf })
				end,
			})

			-- Tailwind on extra templating fts (vue/svelte/eruby/etc.)
			vim.api.nvim_create_autocmd("FileType", {
				pattern = {
					"vue",
					"svelte",
					"heex",
					"eelixir",
					"eruby",
					"templ",
					"javascript",
					"typescript",
					"typescriptreact",
					"javascriptreact",
				},
				callback = function(args)
					vim.lsp.start(vim.lsp.config.tailwindcss, { bufnr = args.buf })
				end,
			})

			-- ===============================
			-- Optional global fallback format
			-- ===============================
			vim.api.nvim_create_autocmd("BufWritePre", {
				pattern = { "*.ts", "*.js", "*.tsx", "*.jsx", "*.json", "*.css", "*.scss", "*.html", "*.md", "*.lua" },
				callback = function()
					vim.lsp.buf.format()
				end,
			})

			-- ===============================
			-- Keymaps
			-- ===============================
			local map = vim.keymap.set
			map("n", "gd", vim.lsp.buf.definition)
			map("n", "gr", vim.lsp.buf.references)
			map("n", "gi", vim.lsp.buf.implementation)
			map("n", "K", vim.lsp.buf.hover)
			map("n", "<leader>rn", vim.lsp.buf.rename)
			map("n", "<leader>ca", vim.lsp.buf.code_action, { noremap = true, silent = true, desc = "LSP Code Action" })
			map("n", "<leader>cb", vim.lsp.buf.format)
			map("n", "[d", vim.diagnostic.goto_prev)
			map("n", "]d", vim.diagnostic.goto_next)
			map("n", "<leader>E", vim.diagnostic.open_float)
			map("n", "<leader>Q", vim.diagnostic.setloclist)
		end,
	},
}
