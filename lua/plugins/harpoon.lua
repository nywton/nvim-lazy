return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local harpoon = require("harpoon")
    local list = harpoon:list()

    vim.keymap.set("n", "<leader>a", function()
      list:add()
    end, { desc = "Harpoon add file" })

    vim.keymap.set("n", "<C-e>", function()
      harpoon.ui:toggle_quick_menu(list)
    end, { desc = "Harpoon quick menu" })

    vim.keymap.set("n", "<C-h>", function()
      list:next()
    end, { desc = "Harpoon next file" })

    vim.keymap.set("n", "<C-t>", function()
      list:prev()
    end, { desc = "Harpoon prev file" })
  end,
}
