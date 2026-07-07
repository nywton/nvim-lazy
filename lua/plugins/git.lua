return {
	{
		"tpope/vim-fugitive",
		cmd = { "Git", "Gvdiffsplit", "Gclog" }, -- Lazy-load only when running these commands
		init = function()
			-- In the Fugitive status buffer, make <CR> open the file in a vertical split.
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "fugitive",
				callback = function()
					vim.keymap.set("n", "<CR>", "gO", {
						buffer = true,
						remap = true,
						silent = true,
						desc = "Open file in vertical split",
					})
				end,
			})
		end,
		keys = {
			-- Git main
			{ "<leader>gg", "<cmd>0Git<CR>", desc = "Open Fugitive status (review hub)" },

			-- Review: side-by-side diff (VSCode-like), working tree vs index/HEAD
			{ "<leader>gv", "<cmd>Gvdiffsplit<CR>", desc = "Side-by-side diff of current file" },

			-- Git basic
			{ "<leader>gb", "<cmd>Git blame<CR>", desc = "Git blame" },
			{ "<leader>gl", "<cmd>Git log<CR>", desc = "Git log -p" },

			-- History & compare
			-- Side-by-side diff vs previous commit (HEAD~1)
			{ "<leader>g-", "<cmd>Gvdiffsplit HEAD~1<CR>", desc = "Diff vs HEAD~1" },
			-- Side-by-side diff vs origin/main (or detected upstream)
			{
				"<leader>gM",
				function()
					local upstream = vim.trim(vim.fn.system("git rev-parse --abbrev-ref '@{u}' 2>/dev/null"))
					local ref = (vim.v.shell_error == 0 and upstream ~= "") and upstream or "origin/main"
					vim.cmd("Gvdiffsplit " .. ref)
				end,
				desc = "Diff vs upstream (origin/main)",
			},

			-- Review incoming commits
			-- Shows commits in upstream not yet in HEAD (run <leader>gF first to fetch)
			{
				"<leader>gi",
				function()
					local upstream = vim.trim(vim.fn.system("git rev-parse --abbrev-ref '@{u}' 2>/dev/null"))
					local ref = (vim.v.shell_error == 0 and upstream ~= "") and upstream or "origin/main"
					vim.cmd("Git log HEAD.." .. ref .. " --oneline")
				end,
				desc = "Incoming commits (unpulled)",
			},
			-- Load every file changed vs upstream into a quickfix diff list → <C-k>/<C-j> to review each
			{
				"<leader>gd",
				function()
					local upstream = vim.trim(vim.fn.system("git rev-parse --abbrev-ref '@{u}' 2>/dev/null"))
					local ref = (vim.v.shell_error == 0 and upstream ~= "") and upstream or "origin/main"
					vim.cmd("Git difftool -y " .. ref)
				end,
				desc = "Difftool all changed files vs upstream → C-k/C-j",
			},

			-- Git workflow
			{
				"<leader>gP",
				function()
					local branch = vim.fn.FugitiveHead()
					vim.cmd("Git push origin " .. branch)
				end,
				desc = "git push origin current-branch",
			},
			{
				"<leader>gp",
				function()
					local branch = vim.fn.FugitiveHead()
					vim.cmd("Git pull origin " .. branch)
				end,
				desc = "git pull origin current-branch",
			},
			{ "<leader>gc", "<cmd>Git commit<CR>", desc = "Git commit" },
			{ "<leader>gC", "<cmd>Git commit --amend<CR>", desc = "Amend last commit" },
			{ "<leader>ga", "<cmd>Git add %<CR>", desc = "Git add current file" },
			{ "<leader>gu", "<cmd>Git restore %<CR>", desc = "Discard changes in current file" },
			{ "<leader>gU", "<cmd>Git reset HEAD %<CR>", desc = "Unstage current file" },
			{ "<leader>gF", "<cmd>Git fetch<CR>", desc = "Git fetch" },

			-- Merge conflicts
			{ "<leader>g1", "<cmd>diffget //2<CR>", desc = "Use our version (diffget //2)" },
			{ "<leader>g2", "<cmd>diffget //3<CR>", desc = "Use their version (diffget //3)" },
			{ "<leader>gr", "<cmd>Git mergetool<CR>", desc = "Run Git mergetool" },
			{ "<leader>gD", "<cmd>Gvdiffsplit!<CR>", desc = "Vertical diff of conflicts" },

			-- Buffer nav (optional, not strictly git-related)
			{ "<leader>bn", "<cmd>bnext<CR>", desc = "Next buffer" },
			{ "<leader>bv", "<cmd>bprevious<CR>", desc = "Previous buffer" },
			{ "<leader>bd", "<cmd>bdelete<CR>", desc = "Delete buffer" },
		},
	},
	{
		"sindrets/diffview.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
		keys = {
			{ "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history (diffview)" },
			{ "<leader>gH", "<cmd>DiffviewFileHistory<CR>", desc = "Repo history (diffview)" },
			-- Morning review: see everything that changed in the last pull
			-- DiffviewOpen  → file panel (all changed files) + hunk diff, Tab/S-Tab walks files
			-- DiffviewFileHistory → commit list, Tab/S-Tab walks commits one by one
			{
				"<leader>go",
				function()
					local has_orig = vim.fn.system("git rev-parse --verify ORIG_HEAD 2>/dev/null"):match("%S")
					if has_orig then
						vim.cmd("DiffviewOpen ORIG_HEAD")
					else
						local upstream = vim.trim(vim.fn.system("git rev-parse --abbrev-ref '@{u}' 2>/dev/null"))
						local ref = (vim.v.shell_error == 0 and upstream ~= "") and upstream or "origin/main"
						vim.cmd("DiffviewOpen " .. ref)
					end
				end,
				desc = "Review last pull — all changed files + hunks",
			},
			{
				"<leader>gO",
				function()
					local has_orig = vim.fn.system("git rev-parse --verify ORIG_HEAD 2>/dev/null"):match("%S")
					if has_orig then
						vim.cmd("DiffviewFileHistory --range=ORIG_HEAD..HEAD")
					else
						local upstream = vim.trim(vim.fn.system("git rev-parse --abbrev-ref '@{u}' 2>/dev/null"))
						local ref = (vim.v.shell_error == 0 and upstream ~= "") and upstream or "origin/main"
						vim.cmd("DiffviewFileHistory --range=" .. ref .. "..HEAD")
					end
				end,
				desc = "Review last pull — commit by commit (Tab to advance)",
			},
		},
		opts = {
			view = {
				file_history = {
					layout = "diff2_horizontal",
				},
			},
		},
	},
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
			numhl = false,
			linehl = false,
			watch_gitdir = {
				interval = 1000,
				follow_files = true,
			},
			current_line_blame = true,
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol", -- "eol" | "overlay" | "right_align"
				delay = 1000,
			},
			sign_priority = 6,
			update_debounce = 100,
			status_formatter = nil, -- Use default
		},
		keys = {
			{ "<leader>hs", ":Gitsigns stage_hunk<CR>", desc = "Stage hunk", mode = "n" },
			{ "<leader>hr", ":Gitsigns reset_hunk<CR>", desc = "Reset hunk", mode = "n" },
			{ "<leader>hS", ":Gitsigns stage_buffer<CR>", desc = "Stage buffer", mode = "n" },
			{ "<leader>hu", ":Gitsigns undo_stage_hunk<CR>", desc = "Undo stage hunk", mode = "n" },
			{ "<leader>hR", ":Gitsigns reset_buffer<CR>", desc = "Reset buffer", mode = "n" },
			{ "<leader>hp", ":Gitsigns preview_hunk<CR>", desc = "Preview hunk", mode = "n" },
			{ "<leader>hb", ":Gitsigns blame_line<CR>", desc = "Blame line", mode = "n" },
			{ "<leader>tb", ":Gitsigns toggle_current_line_blame<CR>", desc = "Toggle blame", mode = "n" },
			{ "<leader>hd", ":Gitsigns diffthis<CR>", desc = "Diff this buffer", mode = "n" },
			{ "<leader>hD", ":Gitsigns diffthis ~<CR>", desc = "Diff against last commit", mode = "n" },
			{ "<leader>td", ":Gitsigns toggle_deleted<CR>", desc = "Toggle deleted", mode = "n" },
		},
		config = function(_, opts)
			require("gitsigns").setup(opts)

			-- Repo-wide hunk nav (]c/[c): the only copy — remap.lua no longer
			-- duplicates this under g]/g[.
			local function get_all_hunks()
				local git_root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
				if vim.v.shell_error ~= 0 then
					return {}
				end

				local hunks = {}
				local seen = {}

				local function parse_diff(lines)
					local current_file = nil
					for _, line in ipairs(lines) do
						local file = line:match("^%+%+%+ b/(.+)$")
						if file then
							current_file = git_root .. "/" .. file
						end
						local lnum = line:match("^@@ %-[%d,]+ %+(%d+)")
						if lnum and current_file then
							local key = current_file .. ":" .. lnum
							if not seen[key] then
								seen[key] = true
								table.insert(hunks, { file = current_file, lnum = tonumber(lnum) })
							end
						end
					end
				end

				parse_diff(vim.fn.systemlist("git -C " .. vim.fn.shellescape(git_root) .. " diff -U0 2>/dev/null"))
				parse_diff(
					vim.fn.systemlist("git -C " .. vim.fn.shellescape(git_root) .. " diff -U0 --cached 2>/dev/null")
				)

				table.sort(hunks, function(a, b)
					if a.file ~= b.file then
						return a.file < b.file
					end
					return a.lnum < b.lnum
				end)

				return hunks
			end

			local function nav_hunk_repowide(direction)
				local hunks = get_all_hunks()
				if #hunks == 0 then
					vim.notify("No uncommitted changes", vim.log.levels.INFO)
					return
				end

				local cur_file = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
				local cur_line = vim.api.nvim_win_get_cursor(0)[1]

				local target_idx
				if direction == "next" then
					for i, h in ipairs(hunks) do
						if h.file > cur_file or (h.file == cur_file and h.lnum > cur_line) then
							target_idx = i
							break
						end
					end
					target_idx = target_idx or 1
				else
					for i = #hunks, 1, -1 do
						local h = hunks[i]
						if h.file < cur_file or (h.file == cur_file and h.lnum < cur_line) then
							target_idx = i
							break
						end
					end
					target_idx = target_idx or #hunks
				end

				local h = hunks[target_idx]
				if h.file ~= cur_file then
					vim.cmd("edit " .. vim.fn.fnameescape(h.file))
				end
				vim.api.nvim_win_set_cursor(0, { h.lnum, 0 })
				vim.cmd("normal! zz")
			end

			vim.keymap.set("n", "]c", function()
				if vim.wo.diff then
					vim.cmd("normal! ]c")
					return
				end
				nav_hunk_repowide("next")
			end, { desc = "Jump to next uncommitted hunk (repo-wide)" })

			vim.keymap.set("n", "[c", function()
				if vim.wo.diff then
					vim.cmd("normal! [c")
					return
				end
				nav_hunk_repowide("prev")
			end, { desc = "Jump to previous uncommitted hunk (repo-wide)" })
		end,
	},
}
