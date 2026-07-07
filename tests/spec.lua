-- =====================================================================
-- Headless feature tests for this Neovim config.
--
-- Run via tests/run.sh, or directly:
--   nvim --headless -c "luafile tests/spec.lua" -c "qa!"
--
-- Exits non-zero if any check fails (so CI catches regressions).
-- Assumes plugins are already installed (run.sh / the Dockerfile do this).
-- =====================================================================

local pass, fail, warned = 0, 0, 0

local function ok(name)
  pass = pass + 1
  print(string.format("ok   - %s", name))
end

local function not_ok(name, msg)
  fail = fail + 1
  print(string.format("FAIL - %s%s", name, msg and ("  (" .. msg .. ")") or ""))
end

local function check(name, cond, msg)
  if cond then ok(name) else not_ok(name, msg) end
end

-- Soft check: report but don't fail the suite (optional/host-dependent tools).
local function soft(name, cond)
  if cond then
    ok(name)
  else
    warned = warned + 1
    print(string.format("warn - %s (optional, not found)", name))
  end
end

print("# config bootstrap")
check("leader is <Space>", vim.g.mapleader == " ")
check("lazy.nvim is loaded", pcall(require, "lazy"))

print("# editor options (settings.lua)")
check("shiftwidth = 2", vim.o.shiftwidth == 2)
check("expandtab on", vim.o.expandtab == true)
check("number on", vim.o.number == true)
check("termguicolors on", vim.o.termguicolors == true)
check("undofile on", vim.o.undofile == true)

print("# external tools on PATH")
check("ripgrep (rg)", vim.fn.executable("rg") == 1)
check("git", vim.fn.executable("git") == 1)
check("fd / fdfind", vim.fn.executable("fd") == 1 or vim.fn.executable("fdfind") == 1)
check("stylua (lua formatter)", vim.fn.executable("stylua") == 1)
-- This config is Node-free by design. We can't assert node is absent (the
-- host may have it for unrelated work), but nothing here installs or requires
-- it — the suite passes with no JS runtime present (proven in the container/CI).
print(string.format("info - node on PATH: %s (not used by this config)",
  vim.fn.executable("node") == 1 and "yes" or "no"))
-- LSP servers and gem/pip formatters are host-dependent (installed by
-- scripts/install.sh, not by any plugin), so report without failing.
-- (JS/TS/HTML/CSS/ERB are formatted dependency-free via Treesitter re-indent;
-- see lua/config/tsformat.lua. No biome / Node tooling is involved.)
soft("ruby-lsp (ruby lsp, via gem)", vim.fn.executable("ruby-lsp") == 1)
soft("black (python formatter)", vim.fn.executable("black") == 1)
soft("rubocop (ruby formatter)", vim.fn.executable("rubocop") == 1)
soft("the silver searcher (ag)", vim.fn.executable("ag") == 1)
soft("tmux", vim.fn.executable("tmux") == 1)

print("# plugins registered with lazy")
local registered = {}
for _, p in ipairs(require("lazy").plugins()) do
  registered[p.name] = true
end
local expected = {
  "lazy.nvim",
  "nvim-treesitter", "nvim-ts-autotag", "conform.nvim",
  "telescope.nvim", "plenary.nvim", "harpoon", "vim-fugitive",
  "diffview.nvim", "gitsigns.nvim", "lualine.nvim", "catppuccin",
  "nvim-autopairs",
}
for _, name in ipairs(expected) do
  check("registered: " .. name, registered[name] == true, "not in lazy spec")
end

print("# keymaps")
check("<leader>tt -> terminal", vim.fn.maparg("<leader>tt", "n") ~= "")
check("<leader>ts -> split terminal", vim.fn.maparg("<leader>ts", "n") ~= "")
check("<leader>e -> netrw toggle", vim.fn.maparg("<leader>e", "n") ~= "")
check("; -> command mode", vim.fn.maparg(";", "n") ~= "")
check("jj -> <Esc> (insert)", vim.fn.maparg("jj", "i") ~= "")
check("<C-f> -> telescope git_files", vim.fn.maparg("<C-f>", "n") ~= "")
check("<leader>s -> live_grep", vim.fn.maparg("<leader>s", "n") ~= "")

print("# force-load lazy plugins and require their modules")
local to_load = {
  "telescope.nvim", "nvim-treesitter", "conform.nvim",
  "gitsigns.nvim", "lualine.nvim",
}
pcall(function() require("lazy").load({ plugins = to_load }) end)

for _, mod in ipairs({
  "telescope", "nvim-treesitter", "conform",
  "gitsigns", "lualine",
}) do
  check("require('" .. mod .. "')", (pcall(require, mod)))
end

print("# LSP / completion / formatting wiring")
-- In 0.11+ vim.lsp.config is a callable *table*; vim.lsp.enable is a function.
check("vim.lsp.config API present (nvim 0.11+)", vim.lsp.config ~= nil and type(vim.lsp.enable) == "function")
-- Servers are configured through core (lua/config/lsp.lua), no mason/lspconfig.
check("ruby_lsp configured via vim.lsp.config", vim.lsp.config.ruby_lsp ~= nil and vim.lsp.config.ruby_lsp.cmd ~= nil)
check("built-in 'autocomplete' enabled (nvim 0.12)", vim.o.autocomplete == true)
local conform_ok, conform = pcall(require, "conform")
check("conform formatters_by_ft has lua/ruby/python",
  conform_ok and conform.formatters_by_ft
    and conform.formatters_by_ft.lua ~= nil
    and conform.formatters_by_ft.ruby ~= nil
    and conform.formatters_by_ft.python ~= nil)

-- ---------------------------------------------------------------------
print(string.rep("-", 50))
print(string.format("%d passed, %d failed, %d warnings", pass, fail, warned))
os.exit(fail == 0 and 0 or 1)
