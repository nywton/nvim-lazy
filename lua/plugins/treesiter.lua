return {
  "nvim-treesitter/nvim-treesitter",
  -- The `main` branch is the rewrite required for Neovim 0.12+.
  -- (The old `master` branch only supports Neovim 0.10/0.11.)
  branch = "main",
  build = ":TSUpdate",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "windwp/nvim-ts-autotag",
  },
  config = function()
    local parsers = {
      "json",
      "javascript",
      "typescript",
      "tsx",
      "yaml",
      "html",
      "css",
      "markdown",
      "markdown_inline",
      "bash",
      "lua",
      "vim",
      "vimdoc",
      "dockerfile",
      "gitignore",
      "ruby",
      "python",
    }

    -- Install runs asynchronously and is a no-op once parsers are present.
    require("nvim-treesitter").install(parsers)

    -- On `main`, modules are gone: highlighting/indent are enabled per buffer.
    -- BufReadPre loads this plugin before FileType fires, so the autocmd is
    -- registered in time for the first real buffer.
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        -- Errors when no parser is installed for the filetype; guard it.
        if pcall(vim.treesitter.start, args.buf) then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })

    -- Auto close/rename HTML/JSX tags (independent of the treesitter modules).
    require("nvim-ts-autotag").setup()
  end,
}
