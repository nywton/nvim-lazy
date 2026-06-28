return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" }, -- lazy-load on buffer open
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
		current_line_blame = false,
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
			parse_diff(vim.fn.systemlist("git -C " .. vim.fn.shellescape(git_root) .. " diff -U0 --cached 2>/dev/null"))

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
}
