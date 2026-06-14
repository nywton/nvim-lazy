return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    -- Backend for the non-blocking notification toasts (pure Lua, no Node).
    "rcarriga/nvim-notify",
  },
  opts = {
    -- Route the noisy first-run install chatter to the small, non-blocking
    -- "mini" view (bottom-right) instead of the blocking hit-enter prompt.
    -- nvim-treesitter (main branch) prints each parser download via
    -- vim.api.nvim_echo, and Mason prints install failures via vim.notify;
    -- noice captures BOTH through the ext_messages UI so neither blocks.
    routes = {
      {
        filter = {
          event = "msg_show",
          any = {
            { find = "Downloading tree%-sitter" },
            { find = "%[nvim%-treesitter" },
            { find = "Language installed" },
            { find = "parsers? are up%-to%-date" },
            { find = "Installed %d+/%d+ languages" },
          },
        },
        view = "mini",
      },
      {
        -- Mason install progress/results: keep visible but non-blocking.
        filter = { event = "notify", any = { { find = "mason" }, { find = "Mason" } } },
        view = "notify",
      },
    },
    -- Hover/signature docs through noice's nicer markdown renderer.
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
    },
    presets = {
      -- Long messages open in a split instead of triggering a more-prompt.
      long_message_to_split = true,
      lsp_doc_border = true,
    },
  },
}
