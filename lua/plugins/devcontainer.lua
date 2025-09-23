return {
  "esensar/nvim-dev-container",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  config = function()
    require("devcontainer").setup({
      config_file_path = "/Users/nywton/Code/syngenta/infra-docker-cropwise-unified-platform/.devcontainer.json",
    })
  end,
}
