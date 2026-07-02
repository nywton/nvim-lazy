local o = vim.opt
local g = vim.g

-- =====================
-- netrw (built-in file explorer)
-- =====================
g.netrw_winsize = 80 -- width of netrw window
g.netrw_banner = 0 -- remove banner
g.netrw_keepdir = 1 -- keep netrw synced with the current directory
g.netrw_localcopydircmd = "cp -r"

-- =====================
-- Editor basics
-- =====================
o.number = true -- Show line numbers
o.relativenumber = false -- Absolute line numbers only
o.cursorline = true -- Highlight the current line
o.mouse = "a" -- Enable mouse support in all modes
o.title = true -- Set terminal/window title
o.showmatch = true -- Highlight matching brackets
o.colorcolumn = "100" -- Ruler at column 100

-- =====================
-- Indentation & tabs
-- =====================
o.autoindent = true -- Copy indent from current line
o.smartindent = true -- Insert indents automatically
o.expandtab = true -- Use spaces instead of tabs
o.shiftwidth = 2 -- Indent width = 2 spaces
o.tabstop = 2 -- A <Tab> counts as 2 spaces
o.softtabstop = 2 -- <Tab> uses 2 spaces while editing

-- =====================
-- Search
-- =====================
o.hlsearch = false -- Don't highlight search matches
o.incsearch = true -- Show matches while typing
o.ignorecase = true -- Case-insensitive search...
o.smartcase = true -- ...unless uppercase is used
o.inccommand = "split" -- Show live preview of :substitute

-- =====================
-- UI & splits
-- =====================
o.wrap = false -- Don't wrap long lines
o.scrolloff = 8 -- Keep 8 lines visible above/below cursor
o.signcolumn = "yes" -- Always show sign column (git/lsp/etc.)
o.termguicolors = true -- Enable 24-bit RGB colors
o.splitbelow = true -- New splits open below
o.splitright = true -- New splits open to the right

-- =====================
-- Performance & behavior
-- =====================
o.ttimeoutlen = 0 -- No delay for mapped key sequences
o.updatetime = 250 -- Faster completion & diagnostics updates
o.hidden = true -- Allow hidden buffers (don't force save)
o.isfname:append("@-@") -- Treat '@' and '-' as part of filenames

-- =====================
-- Files & persistent undo
-- =====================
o.swapfile = false -- Don't use swap files
o.backup = false -- Don't create backup files

local undo_path = vim.fn.stdpath("data") .. "/undodir"
if vim.fn.isdirectory(undo_path) == 0 then
	vim.fn.mkdir(undo_path, "p", 0700)
end
o.undodir = undo_path
o.undofile = true -- Enable persistent undo

-- =====================
-- Clipboard (WSL ↔ Windows)
-- =====================
if vim.fn.has("wsl") == 1 then
	o.clipboard = "unnamedplus"
	g.clipboard = {
		name = "WslClipboard",
		copy = {
			["+"] = "clip.exe",
			["*"] = "clip.exe",
		},
		paste = {
			["+"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
			["*"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
		},
		cache_enabled = 0,
	}
elseif vim.fn.has("linux") == 1 and not (vim.env.DISPLAY or vim.env.WAYLAND_DISPLAY) then
	-- =====================
	-- Headless Linux (Ubuntu server over SSH, docker): OSC 52 clipboard
	-- =====================
	-- No X/Wayland means no xclip/wl-clipboard — "+ yanks travel as OSC 52
	-- escape codes through the terminal (and tmux's set-clipboard passthrough)
	-- to the LOCAL machine's clipboard instead. Neovim only auto-picks OSC 52
	-- when $SSH_TTY is set; forcing it also covers docker exec and consoles.
	-- "+p needs a terminal that answers OSC 52 queries (kitty does);
	-- terminal-native paste always works.
	g.clipboard = "osc52"

	-- gx / :Open can't launch a browser here — copy the URL to the local
	-- clipboard (via OSC 52 above) and say so instead. vim.ui.open is the
	-- documented override point; _get_open_cmd is patched to match so
	-- :checkhealth reports the handler that is actually in effect.
	vim.ui.open = function(path)
		vim.fn.setreg("+", path)
		vim.notify("Copied to local clipboard: " .. path)
		return nil, nil
	end
	vim.ui._get_open_cmd = function()
		return { "osc52-copy-to-local-clipboard" }, nil
	end
end

-- =====================
-- Filetypes core doesn't detect
-- =====================
-- Neovim has no built-in detection for .slim, so without this the installed
-- slim treesitter parser never activates (FileType never fires).
vim.filetype.add({ extension = { slim = "slim" } })

-- =====================
-- rbenv on PATH
-- =====================
-- rbenv's `init` only runs in interactive shells, so a GUI/desktop launch (or
-- a shell started before install) leaves Neovim without `ruby`/`gem` — and
-- with them the `ruby-lsp` and `rubocop` binaries this config expects on PATH.
-- Prepend the shims here so Ruby is visible however Neovim was started.
local rbenv_shims = vim.fn.expand("~/.rbenv/shims")
if vim.fn.isdirectory(rbenv_shims) == 1 and not string.find(vim.env.PATH or "", rbenv_shims, 1, true) then
  vim.env.PATH = rbenv_shims .. ":" .. (vim.env.PATH or "")
end

-- =====================
-- Language providers
-- =====================
-- This config is deliberately Node-free and edits code through an LSP
-- (ruby_lsp), not Neovim's remote-plugin hosts. None of the installed
-- plugins need these providers, so disable them to silence the optional
-- :checkhealth warnings (node/perl/python3/ruby).
g.loaded_node_provider = 0
g.loaded_perl_provider = 0
g.loaded_python3_provider = 0
g.loaded_ruby_provider = 0
