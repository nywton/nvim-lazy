vim.o.cursorline = true
vim.cmd.colorscheme("habamax")

-- lua/git/signs.lua's bare sign-column implementation reads these highlight
-- groups. DiffAdd/DiffChange/DiffDelete are core groups every colorscheme
-- defines, so this stays in sync regardless of which one is active.
vim.api.nvim_set_hl(0, "GitSignsAdd", { link = "DiffAdd" })
vim.api.nvim_set_hl(0, "GitSignsChange", { link = "DiffChange" })
vim.api.nvim_set_hl(0, "GitSignsDelete", { link = "DiffDelete" })

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
