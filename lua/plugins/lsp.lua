return {
  -- Mason + LSP
  {
    "williamboman/mason.nvim",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local mason = require("mason")
      local mason_lspconfig = require("mason-lspconfig")
      local lspconfig = require("lspconfig")
      local util = require("lspconfig.util")

      -- ===============================
      -- Enable local configuration files (project-specific configs) in the current working directory when you start Neovim
      -- Then you can create a file .nvim.lua in the root directory of your project and just change vim.g.ruby_host_prg there
      --- Project-local .nvim.lua config
      -- vim.g.ruby_host_prg = "/Users/nywton/.rbenv/shims/ruby"
      -- ===============================
      vim.o.exrc = true

      -- Ruby executable (which ruby)
      vim.g.ruby_host_prg = "/Users/nywton/.rbenv/shims/ruby"

      -- vim.o.secure = true

      -- ===============================
      -- Diagnostics
      -- ===============================
      vim.o.updatetime = 250
      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
          source = "if_many",
          spacing = 2,
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = "always",
          focusable = false,
          scope = "line",
        },
      })

      vim.api.nvim_create_autocmd("CursorHold", {
        callback = function()
          local diags = vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
          if #diags > 0 then
            vim.diagnostic.open_float(nil, { focus = false })
          end
        end,
      })

      -- ===============================
      -- Mason setup
      -- ===============================
      mason.setup()
      mason_lspconfig.setup({
        ensure_installed = {
          "html",
          "cssls",
          "tailwindcss",
          "ruby_lsp",
          "denols",
        },
      })

      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local on_attach = function(client, bufnr)
        -- format on save
        if client.server_capabilities.documentFormattingProvider then
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = vim.api.nvim_create_augroup("Format", { clear = true }),
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format()
            end,
          })
        end
      end

      local is_deno = function(root_dir)
        return util.root_pattern("deno.json", "deno.jsonc")(root_dir)
      end

      -- LSP configs
      lspconfig.denols.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        root_dir = function(fname)
          if is_deno(fname) then
            return util.root_pattern("deno.json", "deno.jsonc")(fname)
          end
        end,
        init_options = {
          enable = true,
          lint = true,
          unstable = true,
        },
      })

      lspconfig.html.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        filetypes = { "html", "htmx" },
      })

      lspconfig.cssls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        filetypes = { "css", "scss", "less" },
      })

      lspconfig.tailwindcss.setup({
        on_attach = on_attach,
        capabilities = capabilities,
      })

      lspconfig.ruby_lsp.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        filetypes = { "ruby" },
        init_options = { formatter = "auto" },
        settings = {
          rubocop = {
            command = "bundle",
            args = { "exec", "rubocop", "--format", "json" },
          },
        },
      })

      -- Optional global fallback format
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = { "*.ts", "*.js", "*.tsx", "*.jsx", "*.json", "*.css", "*.scss", "*.html", "*.md", "*.lua" },
        callback = function()
          vim.lsp.buf.format()
        end,
      })

      -- Keymaps
      local map = vim.keymap.set
      map("n", "gd", vim.lsp.buf.definition)
      map("n", "gr", vim.lsp.buf.references)
      map("n", "gi", vim.lsp.buf.implementation)
      map("n", "K", vim.lsp.buf.hover)
      map("n", "<leader>rn", vim.lsp.buf.rename)
      map("n", "<leader>ca", vim.lsp.buf.code_action, { noremap = true, silent = true, desc = "LSP Code Action" })
      map("n", "<leader>cb", vim.lsp.buf.format)
      map("n", "[d", vim.diagnostic.goto_prev)
      map("n", "]d", vim.diagnostic.goto_next)
      map("n", "<leader>E", vim.diagnostic.open_float)
      map("n", "<leader>Q", vim.diagnostic.setloclist)
    end,
  },
}
