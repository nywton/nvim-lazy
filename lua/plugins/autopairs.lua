return {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
        require("nvim-autopairs").setup({
            disable_filetype = { "TelescopePrompt", "vim" },
            -- <CR> is owned by the completion mapping in lua/config/lsp.lua,
            -- which calls autopairs_cr() itself when no completion is selected.
            map_cr = false,
        })
    end,
}
