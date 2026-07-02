-- ===========================================================================
-- ctags: fallback code navigation for when LSP is off (see the <leader>lsp
-- toggle in lsp.lua) and for anything ruby_lsp doesn't cover. Zero new
-- plugins — a repo's `tags` file is kept fresh by (a) a debounced regen on
-- save and (b) git hooks this module self-installs into every repo's
-- .git/hooks the first time it's opened, so branch switches/pulls/rebases
-- refresh it too. Plug-and-play across machines: universal-ctags ships via
-- scripts/install.sh, and the hooks are installed per-repo by this file —
-- no global git config, no manual per-machine setup step.
-- ===========================================================================

local M = {}

local MARK_BEGIN = "# >>> nvim-lazy ctags >>>"
local MARK_END = "# <<< nvim-lazy ctags <<<"
local HOOK_NAMES = { "post-checkout", "post-merge", "post-rewrite" }
local HOOK_BLOCK = {
	MARK_BEGIN,
	'command -v ctags >/dev/null 2>&1 && (cd "$(git rev-parse --show-toplevel)" '
		.. '&& nohup ctags -R --exclude=.git -f tags >/dev/null 2>&1 &)',
	MARK_END,
}

local function git_root()
	local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
	if vim.v.shell_error ~= 0 or root == "" then
		return nil
	end
	return root
end

-- Idempotent: no-ops if MARK_BEGIN is already present. Inserts right after
-- the shebang (not at the end) so the block always runs even if the rest of
-- the hook calls `exit` early — never touches the hook's own exit status
-- since the tagging command is backgrounded.
local function install_hook(root, name)
	local path = root .. "/.git/hooks/" .. name
	local lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
	for _, line in ipairs(lines) do
		if line == MARK_BEGIN then
			return
		end
	end
	if #lines == 0 then
		lines = { "#!/usr/bin/env bash", "" }
	end

	local insert_at = (lines[1] and lines[1]:match("^#!")) and 2 or 1
	local new_lines = {}
	vim.list_extend(new_lines, lines, 1, insert_at - 1)
	vim.list_extend(new_lines, HOOK_BLOCK)
	vim.list_extend(new_lines, lines, insert_at, #lines)

	vim.fn.writefile(new_lines, path)
	vim.fn.setfperm(path, "rwxr-xr-x")
end

-- Local, untracked ignore rule (git's own mechanism for "ignore this on my
-- machine only") — never touches the repo's tracked .gitignore.
local function ensure_gitignored(root)
	local path = root .. "/.git/info/exclude"
	local lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
	for _, line in ipairs(lines) do
		if line == "tags" or line == "/tags" then
			return
		end
	end
	table.insert(lines, "tags")
	vim.fn.writefile(lines, path)
end

function M.install_hooks(root)
	root = root or git_root()
	if not root then
		return
	end
	for _, name in ipairs(HOOK_NAMES) do
		install_hook(root, name)
	end
	ensure_gitignored(root)
end

function M.regenerate(root)
	root = root or git_root()
	if not root or vim.fn.executable("ctags") == 0 then
		return
	end
	vim.system({ "ctags", "-R", "--exclude=.git", "-f", "tags" }, { cwd = root, detach = true })
end

-- Self-install hooks (cheap, idempotent) the first time a repo is seen this
-- session, whenever a git repo is entered or `:cd`'d into.
local installed = {}
vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
	callback = function()
		local root = git_root()
		if root and not installed[root] then
			installed[root] = true
			M.install_hooks(root)
		end
	end,
})

-- Debounced regen on save so navigation stays accurate without waiting for
-- a commit/checkout/merge to trigger the git hooks above.
local debounce_timer = vim.uv.new_timer()
vim.api.nvim_create_autocmd("BufWritePost", {
	callback = function()
		local root = git_root()
		if not root then
			return
		end
		debounce_timer:stop()
		debounce_timer:start(1500, 0, function()
			vim.schedule(function()
				M.regenerate(root)
			end)
		end)
	end,
})

vim.api.nvim_create_user_command("CtagsRegenerate", function()
	local root = git_root()
	if not root then
		vim.notify("Not inside a git repo", vim.log.levels.WARN)
		return
	end
	vim.notify("Regenerating tags…", vim.log.levels.INFO)
	M.regenerate(root)
end, { desc = "Regenerate ctags for the current repo" })

return M
