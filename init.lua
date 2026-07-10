vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("core.options")
require("core.providers")

require("core.colorscheme")

require("core.keymaps.general")
require("core.keymaps.editing")
require("core.keymaps.navigation")
require("core.keymaps.windows")

require("completion")

require("ui.statusline")

require("git.keymaps")
require("git.signs").setup()
require("terminal")
require("neovide")
