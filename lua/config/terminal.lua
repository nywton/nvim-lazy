-- =====================
-- Quick terminal switcher
-- =====================
-- A lightweight, plugin-free toggleable terminal. Keeps one reusable
-- terminal buffer per "kind" (float / split) so toggling never spawns
-- a brand new shell unless the old one was closed.

local state = {
	float = { buf = -1, win = -1 },
	split = { buf = -1, win = -1 },
}

local function open_win(kind)
	if kind == "float" then
		local width = math.floor(vim.o.columns * 0.8)
		local height = math.floor(vim.o.lines * 0.8)
		return vim.api.nvim_open_win(state.float.buf, true, {
			relative = "editor",
			width = width,
			height = height,
			row = math.floor((vim.o.lines - height) / 2),
			col = math.floor((vim.o.columns - width) / 2),
			style = "minimal",
			border = "rounded",
			title = " terminal ",
			title_pos = "center",
		})
	else
		vim.cmd("botright split")
		vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * 0.3))
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, state.split.buf)
		return win
	end
end

local function toggle(kind)
	local t = state[kind]

	-- Already visible -> hide it.
	if vim.api.nvim_win_is_valid(t.win) then
		vim.api.nvim_win_hide(t.win)
		t.win = -1
		return
	end

	-- Create a fresh terminal buffer if we don't have a live one.
	if not vim.api.nvim_buf_is_valid(t.buf) then
		t.buf = vim.api.nvim_create_buf(false, true)
	end

	t.win = open_win(kind)

	-- Start a shell only once per buffer.
	if vim.bo[t.buf].buftype ~= "terminal" then
		vim.fn.jobstart(vim.o.shell, { term = true })
	end

	vim.cmd("startinsert")
end

-- Keymaps -----------------------------------------------------------------
-- <leader>tt -> floating terminal, <leader>ts -> bottom split terminal.
vim.keymap.set("n", "<leader>tt", function()
	toggle("float")
end, { desc = "Toggle floating terminal" })

vim.keymap.set("n", "<leader>ts", function()
	toggle("split")
end, { desc = "Toggle split terminal" })

-- Same chords work from inside the terminal to hide it quickly.
vim.keymap.set("t", "<leader>tt", function()
	toggle("float")
end, { desc = "Toggle floating terminal" })

vim.keymap.set("t", "<leader>ts", function()
	toggle("split")
end, { desc = "Toggle split terminal" })

-- Escape terminal-insert mode with <Esc><Esc>.
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Terminal: normal mode" })

-- No line numbers / sign column in terminal buffers.
vim.api.nvim_create_autocmd("TermOpen", {
	callback = function()
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "no"
	end,
})
