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

print("# editor options (core/options.lua)")
check("shiftwidth = 2", vim.o.shiftwidth == 2)
check("expandtab on", vim.o.expandtab == true)
check("number on", vim.o.number == true)
check("termguicolors on", vim.o.termguicolors == true)
check("undofile on", vim.o.undofile == true)

print("# external tools on PATH")
-- This config has no LSP, no ctags, and no format-on-save by design — code
-- navigation and search are entirely rg+fzf (lua/finder/*.lua), so both are
-- hard requirements, not optional.
check("ripgrep (rg)", vim.fn.executable("rg") == 1)
check("git", vim.fn.executable("git") == 1)
check("fzf", vim.fn.executable("fzf") == 1)
-- This config is Node-free by design. We can't assert node is absent (the
-- host may have it for unrelated work), but nothing here installs or requires
-- it — the suite passes with no JS runtime present (proven in the container/CI).
print(string.format("info - node on PATH: %s (not used by this config)",
  vim.fn.executable("node") == 1 and "yes" or "no"))
soft("tmux", vim.fn.executable("tmux") == 1)

print("# plugins registered with lazy")
local registered = {}
for _, p in ipairs(require("lazy").plugins()) do
  registered[p.name] = true
end
local expected = { "lazy.nvim", "nvim-treesitter", "catppuccin" }
for _, name in ipairs(expected) do
  check("registered: " .. name, registered[name] == true, "not in lazy spec")
end
-- This config deliberately keeps only the two plugins above (colorscheme +
-- treesitter) — everything else (finder, git, statusline, terminal, LSP nav
-- fallback) is plain Lua. Fail if something new sneaks into the spec unnoticed.
local extra = {}
for name, _ in pairs(registered) do
  if name ~= "lazy.nvim" and name ~= "nvim-treesitter" and name ~= "catppuccin" then
    table.insert(extra, name)
  end
end
check("no unexpected plugins registered", #extra == 0, table.concat(extra, ", "))

print("# keymaps")
check("<leader>tt -> terminal", vim.fn.maparg("<leader>tt", "n") ~= "")
check("<leader>ts -> split terminal", vim.fn.maparg("<leader>ts", "n") ~= "")
check("<leader>e -> netrw toggle", vim.fn.maparg("<leader>e", "n") ~= "")
check("; -> command mode", vim.fn.maparg(";", "n") ~= "")
check("jj -> <Esc> (insert)", vim.fn.maparg("jj", "i") ~= "")
check("<C-p> -> rg+fzf find files", vim.fn.maparg("<C-p>", "n") ~= "")
check("<leader>s -> rg live grep (quickfix)", vim.fn.maparg("<leader>s", "n") ~= "")
check("<leader>gg -> git status", vim.fn.maparg("<leader>gg", "n") ~= "")
check("gd -> rg+fzf navigation (no LSP/ctags)", vim.fn.maparg("gd", "n") ~= "")
check("gi -> rg+fzf navigation (no LSP/ctags)", vim.fn.maparg("gi", "n") ~= "")
check("gr -> rg+fzf navigation (no LSP/ctags)", vim.fn.maparg("gr", "n") ~= "")

print("# force-load lazy plugins and require their modules")
pcall(function() require("lazy").load({ plugins = { "nvim-treesitter" } }) end)
for _, mod in ipairs({ "nvim-treesitter", "catppuccin" }) do
  check("require('" .. mod .. "')", (pcall(require, mod)))
end

print("# custom modules load cleanly")
for _, mod in ipairs({
  "finder.files", "finder.grep", "finder.quickset",
  "git.commands", "git.hunks", "ui.statusline",
}) do
  check("require('" .. mod .. "')", (pcall(require, mod)))
end

-- ---------------------------------------------------------------------
print(string.rep("-", 50))
print(string.format("%d passed, %d failed, %d warnings", pass, fail, warned))
os.exit(fail == 0 and 0 or 1)
