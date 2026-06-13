return {
	-- Maintained successor to the (now-unmaintained) norcalli/nvim-colorizer.lua;
	-- same setup API, without the deprecated vim.tbl_flatten calls.
	"catgoose/nvim-colorizer.lua",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		filetypes = { "css", "scss", "html", "javascript", "typescript", "lua" },
	},
}
