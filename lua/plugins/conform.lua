return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    -- Single source of truth for format-on-save. Filetypes without a
    -- formatter listed here fall back to the language server (js/ts/css/html).
    formatters_by_ft = {
      lua = { "stylua" },
      ruby = { "rubocop" },
      python = { "black" },
    },
    format_on_save = {
      timeout_ms = 1000,
      lsp_format = "fallback",
    },
  },
}
