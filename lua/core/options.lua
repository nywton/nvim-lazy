local o = vim.opt
local g = vim.g

-- netrw (built-in file explorer)
g.netrw_winsize = 80
g.netrw_banner = 0
g.netrw_keepdir = 1
g.netrw_localcopydircmd = "cp -r"

-- Editor basics
o.number = true
o.relativenumber = false
o.cursorline = true
o.mouse = "a"
o.title = true
o.showmatch = true
o.colorcolumn = "100"

-- Indentation
o.autoindent = true
o.smartindent = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2

-- Search
o.hlsearch = false
o.incsearch = true
o.ignorecase = true
o.smartcase = true
o.inccommand = "split"

-- UI & splits
o.wrap = false
o.scrolloff = 8
o.signcolumn = "yes"
o.termguicolors = true
o.splitbelow = true
o.splitright = true

-- Performance & behavior
o.ttimeoutlen = 0
o.updatetime = 250
o.hidden = true
o.isfname:append("@-@")

-- Files & persistent undo
o.swapfile = false
o.backup = false
local undo_path = vim.fn.stdpath("data") .. "/undodir"
if vim.fn.isdirectory(undo_path) == 0 then
  -- prot MUST be a string: a bare Lua 0700 is decimal 700, not octal, and
  -- yields garbage permissions (e.g. owner write-only, no read/exec) that
  -- break undofile writes into a freshly created directory.
  vim.fn.mkdir(undo_path, "p", "0700")
end
o.undodir = undo_path
o.undofile = true

-- Built-in fuzzy-ish command-line completion (used by :help, :b, etc. in
-- place of telescope's help_tags/buffers pickers).
o.wildmode = "longest:full,full"
o.wildmenu = true

-- ripgrep-backed :grep (finder/grep.lua)
o.grepprg = "rg --vimgrep --smart-case --hidden --glob '!.git'"
o.grepformat = "%f:%l:%c:%m"
