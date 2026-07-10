-- =====================
-- Neovide GUI settings
-- =====================
-- Only applied when running inside Neovide. https://neovide.dev/configuration.html
if not vim.g.neovide then
	return
end

local g = vim.g
local o = vim.opt

-- Font (Neovide ignores terminal font settings)
o.guifont = "JetBrainsMono Nerd Font:h13"

-- =====================
-- Blurred floating windows
-- https://neovide.dev/features.html#blurred-floating-windows
-- =====================
-- Floating windows (completion, hover, telescope, etc.) need some
-- transparency for the blur behind them to be visible.
o.winblend = 30 -- transparency of floating windows
o.pumblend = 30 -- transparency of the popup menu

-- Gaussian blur radius applied behind floating windows.
g.neovide_floating_blur_amount_x = 3.0
g.neovide_floating_blur_amount_y = 3.0

-- Soft drop shadow cast by floating windows.
g.neovide_floating_shadow = true
g.neovide_floating_z_height = 10
g.neovide_light_angle_degrees = 45
g.neovide_light_radius = 5

-- Slight overall window transparency (lets the blur read against the desktop).
g.neovide_opacity = 0.95
g.neovide_normal_opacity = 0.95

-- Blur the area behind the whole Neovide window (macOS / Wayland).
g.neovide_window_blurred = true

-- =====================
-- Feel / polish
-- =====================
g.neovide_cursor_animation_length = 0.05
g.neovide_cursor_trail_size = 0.3
g.neovide_scroll_animation_length = 0.2
g.neovide_refresh_rate = 60
g.neovide_input_macos_option_key_is_meta = "only_left"

-- Toggle fullscreen with <D-CR> (Cmd+Enter)
vim.keymap.set("n", "<D-CR>", function()
	g.neovide_fullscreen = not g.neovide_fullscreen
end, { desc = "Neovide: toggle fullscreen" })

-- Standard Cmd+C / Cmd+V clipboard support
vim.keymap.set({ "n", "v" }, "<D-c>", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set({ "n", "v" }, "<D-v>", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("i", "<D-v>", "<C-r>+", { desc = "Paste from system clipboard" })
vim.keymap.set("c", "<D-v>", "<C-r>+", { desc = "Paste from system clipboard" })
