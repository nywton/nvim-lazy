return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main", -- rewrite required for Neovim 0.12+
  build = ":TSUpdate",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local parsers = require("core.treesitter_parsers")

    vim.defer_fn(function()
      require("nvim-treesitter").install(parsers)
    end, 300)

    -- On `main`, modules are gone: highlighting/indent enabled per buffer.
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        if pcall(vim.treesitter.start, args.buf) then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
