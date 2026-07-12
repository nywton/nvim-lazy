vim.o.cursorline = true
vim.cmd.colorscheme("catppuccin")

-- lua/git/signs.lua's bare sign-column implementation reads these highlight
-- groups. DiffAdd/DiffChange/DiffDelete are core groups every colorscheme
-- defines, so this stays in sync regardless of which one is active.
vim.api.nvim_set_hl(0, "GitSignsAdd", { link = "DiffAdd" })
vim.api.nvim_set_hl(0, "GitSignsChange", { link = "DiffChange" })
vim.api.nvim_set_hl(0, "GitSignsDelete", { link = "DiffDelete" })

-- Staged hunks (already `git add`ed — see git/review.lua's hunk-level
-- accept) get a dimmed sign instead of the same bright one unstaged hunks
-- use, so the gutter actually shows two states instead of one. Linked to
-- Comment rather than a hardcoded color so it stays legible under any
-- colorscheme, matching the groups above.
vim.api.nvim_set_hl(0, "GitSignsStagedAdd", { link = "Comment" })
vim.api.nvim_set_hl(0, "GitSignsStagedChange", { link = "Comment" })
vim.api.nvim_set_hl(0, "GitSignsStagedDelete", { link = "Comment" })

-- Transparent background — let the terminal's own background (and its
-- transparency, if any) show through instead of habamax painting one.
-- Skipped under Neovide: it's a GUI window, not a terminal, and already
-- gets its own opacity/blur from neovide.lua.
if not vim.g.neovide then
	local transparent_groups = {
		"Normal",
		"NormalNC",
		"NormalFloat",
		"FloatBorder",
		"SignColumn",
		"LineNr",
		"CursorLineNr",
		"EndOfBuffer",
		"VertSplit",
		"WinSeparator",
		"StatusLine",
		"StatusLineNC",
		"Pmenu",
	}
	for _, group in ipairs(transparent_groups) do
		local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
		hl.bg = nil
		hl.ctermbg = nil
		vim.api.nvim_set_hl(0, group, hl)
	end
end
