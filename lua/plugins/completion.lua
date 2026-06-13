return {
  "saghen/blink.cmp",
  version = "1.*", -- use a released tag (ships a prebuilt fuzzy-matching binary)
  event = "InsertEnter",
  opts = {
    keymap = {
      preset = "none",
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<CR>"] = { "accept", "fallback" },
      ["<Tab>"] = { "select_next", "fallback" },
      ["<S-Tab>"] = { "select_prev", "fallback" },
    },
    completion = {
      menu = { auto_show = true },
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    -- Completion in `/`, `?` and `:` (replaces cmp-cmdline)
    cmdline = { enabled = true },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
}
