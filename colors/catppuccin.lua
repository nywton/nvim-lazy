-- Catppuccin (Mocha) — hand-authored from the published palette at
-- https://github.com/catppuccin/nvim/blob/main/lua/catppuccin/palettes/mocha.lua
--
-- This config has no plugin manager, so upstream catppuccin/nvim (a
-- multi-file plugin with treesitter/LSP-plugin integrations this config has
-- no use for) isn't vendored wholesale. Instead this file sets only the
-- highlight groups this config actually renders: core UI, legacy :syntax
-- groups, and the treesitter capture groups used by finder.preview and
-- git.diffsplit's opportunistic vim.treesitter.start().

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
	vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.g.colors_name = "catppuccin"

local c = {
	rosewater = "#f5e0dc",
	flamingo = "#f2cdcd",
	pink = "#f5c2e7",
	mauve = "#cba6f7",
	red = "#f38ba8",
	maroon = "#eba0ac",
	peach = "#fab387",
	yellow = "#f9e2af",
	green = "#a6e3a1",
	teal = "#94e2d5",
	sky = "#89dceb",
	sapphire = "#74c7ec",
	blue = "#89b4fa",
	lavender = "#b4befe",
	text = "#cdd6f4",
	subtext1 = "#bac2de",
	subtext0 = "#a6adc8",
	overlay2 = "#9399b2",
	overlay1 = "#7f849c",
	overlay0 = "#6c7086",
	surface2 = "#585b70",
	surface1 = "#45475a",
	surface0 = "#313244",
	base = "#1e1e2e",
	mantle = "#181825",
	crust = "#11111b",
}

local function hl(group, opts)
	vim.api.nvim_set_hl(0, group, opts)
end

-- Core UI
hl("Normal", { fg = c.text, bg = c.base })
hl("NormalFloat", { fg = c.text, bg = c.mantle })
hl("FloatBorder", { fg = c.blue, bg = c.mantle })
hl("FloatTitle", { fg = c.blue, bg = c.mantle, bold = true })
hl("ColorColumn", { bg = c.surface0 })
hl("Cursor", { fg = c.base, bg = c.text })
hl("CursorLine", { bg = c.surface0 })
hl("CursorLineNr", { fg = c.lavender, bold = true })
hl("LineNr", { fg = c.overlay0 })
hl("SignColumn", { fg = c.overlay0, bg = c.base })
hl("VertSplit", { fg = c.surface0 })
hl("WinSeparator", { fg = c.surface0 })
hl("StatusLine", { fg = c.text, bg = c.surface0 })
hl("StatusLineNC", { fg = c.overlay0, bg = c.mantle })
hl("Pmenu", { fg = c.overlay2, bg = c.surface0 })
hl("PmenuSel", { fg = c.base, bg = c.blue, bold = true })
hl("PmenuSbar", { bg = c.surface1 })
hl("PmenuThumb", { bg = c.overlay0 })
hl("Visual", { bg = c.surface1 })
hl("VisualNOS", { bg = c.surface1 })
hl("Search", { fg = c.base, bg = c.yellow })
hl("IncSearch", { fg = c.base, bg = c.peach })
hl("CurSearch", { fg = c.base, bg = c.red })
hl("MatchParen", { fg = c.peach, bold = true, underline = true })
hl("NonText", { fg = c.surface1 })
hl("EndOfBuffer", { fg = c.surface1 })
hl("Whitespace", { fg = c.surface1 })
hl("Title", { fg = c.blue, bold = true })
hl("Directory", { fg = c.blue })
hl("ErrorMsg", { fg = c.red })
hl("WarningMsg", { fg = c.yellow })
hl("ModeMsg", { fg = c.text })
hl("MoreMsg", { fg = c.green })
hl("Question", { fg = c.blue })
hl("WildMenu", { fg = c.base, bg = c.blue })
hl("FoldColumn", { fg = c.overlay0 })
hl("Folded", { fg = c.overlay1, bg = c.surface0 })
hl("SpellBad", { sp = c.red, undercurl = true })
hl("SpellCap", { sp = c.yellow, undercurl = true })
hl("SpellLocal", { sp = c.teal, undercurl = true })
hl("SpellRare", { sp = c.pink, undercurl = true })

-- Diff
hl("DiffAdd", { fg = c.green, bg = c.surface0 })
hl("DiffChange", { fg = c.yellow, bg = c.surface0 })
hl("DiffDelete", { fg = c.red, bg = c.surface0 })
hl("DiffText", { fg = c.blue, bg = c.surface1, bold = true })

-- Diagnostics
hl("DiagnosticError", { fg = c.red })
hl("DiagnosticWarn", { fg = c.yellow })
hl("DiagnosticInfo", { fg = c.sky })
hl("DiagnosticHint", { fg = c.teal })
hl("DiagnosticOk", { fg = c.green })
hl("DiagnosticUnderlineError", { sp = c.red, undercurl = true })
hl("DiagnosticUnderlineWarn", { sp = c.yellow, undercurl = true })
hl("DiagnosticUnderlineInfo", { sp = c.sky, undercurl = true })
hl("DiagnosticUnderlineHint", { sp = c.teal, undercurl = true })

-- Legacy :syntax groups
hl("Comment", { fg = c.overlay1, italic = true })
hl("Constant", { fg = c.peach })
hl("String", { fg = c.green })
hl("Character", { fg = c.teal })
hl("Number", { fg = c.peach })
hl("Boolean", { fg = c.peach })
hl("Float", { fg = c.peach })
hl("Identifier", { fg = c.flamingo })
hl("Function", { fg = c.blue })
hl("Statement", { fg = c.mauve })
hl("Conditional", { fg = c.mauve })
hl("Repeat", { fg = c.mauve })
hl("Label", { fg = c.sapphire })
hl("Operator", { fg = c.sky })
hl("Keyword", { fg = c.mauve })
hl("Exception", { fg = c.mauve })
hl("PreProc", { fg = c.pink })
hl("Include", { fg = c.mauve })
hl("Define", { fg = c.pink })
hl("Macro", { fg = c.pink })
hl("Type", { fg = c.yellow })
hl("StorageClass", { fg = c.yellow })
hl("Structure", { fg = c.yellow })
hl("Typedef", { fg = c.yellow })
hl("Special", { fg = c.pink })
hl("SpecialChar", { fg = c.pink })
hl("Tag", { fg = c.mauve })
hl("Delimiter", { fg = c.overlay2 })
hl("SpecialComment", { fg = c.overlay1 })
hl("Debug", { fg = c.red })
hl("Underlined", { fg = c.blue, underline = true })
hl("Ignore", { fg = c.overlay0 })
hl("Error", { fg = c.red, bold = true })
hl("Todo", { fg = c.base, bg = c.yellow, bold = true })

-- Treesitter capture groups (used by finder.preview and git.diffsplit's
-- opportunistic vim.treesitter.start() — this config has no treesitter
-- plugin, so only parsers bundled with Neovim itself will ever hit these).
hl("@variable", { fg = c.text })
hl("@variable.builtin", { fg = c.red, italic = true })
hl("@variable.parameter", { fg = c.maroon, italic = true })
hl("@constant", { link = "Constant" })
hl("@constant.builtin", { fg = c.peach, italic = true })
hl("@string", { link = "String" })
hl("@string.escape", { fg = c.pink })
hl("@character", { link = "Character" })
hl("@number", { link = "Number" })
hl("@boolean", { link = "Boolean" })
hl("@float", { link = "Float" })
hl("@function", { link = "Function" })
hl("@function.builtin", { fg = c.blue, italic = true })
hl("@function.call", { link = "Function" })
hl("@method", { fg = c.blue })
hl("@method.call", { fg = c.blue })
hl("@constructor", { fg = c.sapphire })
hl("@parameter", { fg = c.maroon, italic = true })
hl("@keyword", { link = "Keyword" })
hl("@keyword.function", { fg = c.mauve, italic = true })
hl("@keyword.return", { fg = c.mauve, italic = true })
hl("@conditional", { link = "Conditional" })
hl("@repeat", { link = "Repeat" })
hl("@label", { link = "Label" })
hl("@operator", { link = "Operator" })
hl("@exception", { link = "Exception" })
hl("@type", { link = "Type" })
hl("@type.builtin", { fg = c.yellow, italic = true })
hl("@property", { fg = c.lavender })
hl("@field", { fg = c.lavender })
hl("@namespace", { fg = c.yellow })
hl("@punctuation.delimiter", { fg = c.overlay2 })
hl("@punctuation.bracket", { fg = c.overlay2 })
hl("@punctuation.special", { fg = c.sky })
hl("@comment", { link = "Comment" })
hl("@tag", { link = "Tag" })
hl("@tag.attribute", { fg = c.mauve, italic = true })
hl("@tag.delimiter", { fg = c.teal })
hl("@markup.heading", { fg = c.blue, bold = true })
hl("@markup.strong", { bold = true })
hl("@markup.italic", { italic = true })
hl("@markup.link", { fg = c.blue, underline = true })
hl("@markup.link.url", { fg = c.teal, underline = true })
