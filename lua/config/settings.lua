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
end
