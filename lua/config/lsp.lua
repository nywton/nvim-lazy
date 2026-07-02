-- ===========================================================================
-- LSP + completion on Neovim core only (0.11+ `vim.lsp.config`/`vim.lsp.enable`,
-- 0.12 built-in 'autocomplete'). No mason / nvim-lspconfig / blink.cmp — the
-- server is a plain binary on PATH, installed by scripts/install.sh
-- (ruby-lsp via gem).
-- ===========================================================================

-- Allow project-local config (.nvim.lua / .exrc), with the built-in trust prompt
vim.o.exrc = true

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
-- Servers (cmd/filetypes/root markers written out here — these used to come
-- from nvim-lspconfig's defaults). Node-free: ruby-lsp is a gem. Python gets
-- Treesitter highlighting + black formatting (conform), no language server.
-- ===============================
vim.lsp.config("ruby_lsp", {
	cmd = { "ruby-lsp" },
	filetypes = { "ruby", "eruby" },
	root_markers = { "Gemfile", ".git" },
	-- glibc arena cap: biggest single RSS win for a long-lived Ruby process.
	cmd_env = { MALLOC_ARENA_MAX = "2" },
	init_options = {
		formatter = "none", -- conform already runs rubocop on save
		linters = {}, -- no in-server RuboCop diagnostics
		enabledFeatures = {
			semanticHighlighting = false, -- Treesitter already highlights
			inlayHint = false,
			codeLens = false,
			foldingRanges = false,
			documentHighlights = false,
			onTypeFormatting = false,
		},
		indexing = {
			excludedPatterns = { "**/spec/fixtures/**", "**/vendor/**", "**/tmp/**", "**/node_modules/**" },
		},
	},
})

vim.lsp.enable({ "ruby_lsp" })

-- ===============================
-- Completion: the built-in 'autocomplete' option (nvim 0.12). The popup opens
-- as you type; sources come from 'complete'. On LspAttach the buffer gets the
-- LSP (omnifunc, "o") as the first source, then buffer words — the same mix
-- blink.cmp provided, with zero plugins.
-- ===============================
vim.o.autocomplete = true
vim.o.completeopt = "menuone,noselect,popup,fuzzy"
vim.opt.shortmess:append("c") -- no "match x of y" messages while completing

local t = function(keys)
	return vim.api.nvim_replace_termcodes(keys, true, true, true)
end

vim.keymap.set("i", "<Tab>", function()
	return vim.fn.pumvisible() == 1 and t("<C-n>") or t("<Tab>")
end, { expr = true, replace_keycodes = false, silent = true })

vim.keymap.set("i", "<S-Tab>", function()
	return vim.fn.pumvisible() == 1 and t("<C-p>") or t("<S-Tab>")
end, { expr = true, replace_keycodes = false, silent = true })

-- <CR> accepts the selected completion item; otherwise defers to
-- nvim-autopairs (its own <CR> map is disabled — see plugins/autopairs.lua).
vim.keymap.set("i", "<CR>", function()
	if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected >= 0 then
		return t("<C-y>")
	end
	local ok, npairs = pcall(require, "nvim-autopairs")
	if ok then
		return npairs.autopairs_cr()
	end
	return t("<CR>")
end, { expr = true, replace_keycodes = false, silent = true })

-- ===============================
-- Keymaps (set when a server attaches)
-- ===============================
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		-- LSP first ("o" = omnifunc, set by the client on attach), then the
		-- current + visible + listed buffers, capped at 5 candidates each.
		vim.bo[args.buf].complete = "o,.^5,w^5,b^5"

		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
		end
		map("n", "gd", vim.lsp.buf.definition, "Go to definition")
		map("n", "gr", vim.lsp.buf.references, "References")
		map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
		map("n", "K", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover docs")
		map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
		map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
		map("n", "<leader>cb", vim.lsp.buf.format, "Format buffer")
		map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, "Previous diagnostic")
		map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next diagnostic")
		map("n", "<leader>E", vim.diagnostic.open_float, "Line diagnostics")
		map("n", "<leader>Q", vim.diagnostic.setloclist, "Diagnostics to loclist")
	end,
})
