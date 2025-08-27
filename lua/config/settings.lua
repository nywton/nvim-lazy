local global = vim.g
local o = vim.opt

-- =====================
-- Editor basics
-- =====================
o.number = true               -- Show line numbers
o.relativenumber = true       -- Show relative line numbers
o.cursorline = true           -- Highlight the current line
o.mouse = "a"                 -- Enable mouse support in all modes
o.encoding = "UTF-8"          -- Internal character encoding
o.syntax = "on"               -- Enable syntax highlighting
o.title = true                -- Set terminal/window title
o.ruler = true                -- Show cursor position in status line
o.showcmd = true              -- Show partial commands in status line
o.showmatch = true            -- Highlight matching brackets

-- =====================
-- Indentation & tabs
-- =====================
o.autoindent = true           -- Copy indent from current line
o.expandtab = true            -- Use spaces instead of tabs
o.shiftwidth = 2              -- Indent width = 2 spaces
o.tabstop = 2                 -- A <Tab> counts as 2 spaces

-- =====================
-- Search
-- =====================
o.hlsearch = false            -- Don’t highlight search matches
o.incsearch = true            -- Show matches while typing
o.ignorecase = true           -- Case-insensitive search...
o.smartcase = true            -- ...unless uppercase is used
o.inccommand = "split"        -- Show live preview of :substitute

-- =====================
-- UI & splits
-- =====================
o.wrap = false                -- Don’t wrap long lines
o.scrolloff = 8               -- Keep 8 lines visible above/below cursor
o.signcolumn = "yes"          -- Always show sign column
o.termguicolors = true        -- Enable 24-bit RGB colors
o.splitbelow = true           -- New splits open below
o.splitright = true           -- New splits open to the right
o.colorcolumn = "100"       -- Optional: ruler at column 80

-- =====================
-- Performance
-- =====================
o.ttimeoutlen = 0             -- No delay for mapped key sequences
o.updatetime = 200             -- Faster completion & diagnostics updates
o.wildmenu = true             -- Enhanced command-line completion
o.hidden = true               -- Allow hidden buffers (don’t force save)

-- =====================
-- Files
-- =====================
o.swapfile = false            -- Don’t use swap files
o.backup = false              -- Don’t create backup files

-- =====================
-- Persistent undo
-- =====================
local undo_path = vim.fn.stdpath("data") .. "/undodir"

if vim.fn.isdirectory(undo_path) == 0 then
  vim.fn.mkdir(undo_path, "p", 0700)  -- Create undo dir if missing
end
o.undodir = undo_path
o.undofile = true

-- =====================
-- Clipboard
-- =====================
-- o.clipboard = "unnamedplus"   -- Use system clipboard

-- Special handling for WSL
if vim.fn.has("wsl") == 1 then
  o.clipboard = "unnamedplus"
  global.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = [[powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))]],
      ["*"] = [[powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))]],
    },
    cache_enabled = 0,
  }
end

vim.opt.nu = true                     -- Show line numbers
vim.opt.number = true                 -- Show line number in front of each line
vim.opt.relativenumber = false        -- Show relative line numbers

vim.opt.tabstop = 2                   -- Number of spaces that a <Tab> counts for
vim.opt.softtabstop = 2               -- Number of spaces a <Tab> uses while editing
vim.opt.shiftwidth = 2                -- Number of spaces to use for autoindent
vim.opt.expandtab = true              -- Convert tabs into spaces

vim.opt.smartindent = true            -- Insert indents automatically

vim.opt.wrap = false                  -- Disable line wrapping

vim.opt.swapfile = false              -- Don’t use swap files
vim.opt.backup = false                -- Don’t create backup files


vim.o.undodir = undo_path            -- Set undo directory
vim.o.undofile = true                -- Enable persistent undo

vim.opt.hlsearch = false             -- Don’t highlight search matches
vim.opt.incsearch = true             -- Show matches while typing

vim.opt.scrolloff = 8                -- Keep 8 lines visible above/below cursor
vim.opt.signcolumn = "yes"           -- Always show sign column (for git/lsp/etc.)
vim.opt.isfname:append("@-@")        -- Treat '@' and '-' as part of filenames

vim.opt.updatetime = 50              -- Faster updates (useful for diagnostics)

-- vim.opt.colorcolumn = "80"         -- Show a vertical line at column 80

vim.opt.termguicolors = true         -- Enable 24-bit RGB colors in the terminal

-- WslClipboard setup for WSL ↔ Windows copy/paste
if vim.fn.has('wsl') == 1 then
  vim.opt.clipboard = 'unnamedplus'  -- Use system clipboard by default

  vim.g.clipboard = {
    name = 'WslClipboard',           -- Custom clipboard integration
    copy = {
      ['+'] = 'clip.exe',            -- Copy to Windows clipboard
      ['*'] = 'clip.exe',            -- Copy to Windows clipboard
    },
    paste = {
      ['+'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))', -- Paste from Windows clipboard
      ['*'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))', -- Paste from Windows clipboard
    },
    cache_enabled = 0,               -- Disable clipboard cache
  }
end

