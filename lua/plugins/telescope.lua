return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope", -- load only when :Telescope is called
    keys = {
      { "<leader>f", "<cmd>Telescope find_files<CR>", desc = "Search all files" },
      { "<leader>ks", "<cmd>Telescope keymaps<CR>", desc = "Search all keymaps" },
      { "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "Git status" },
      { "<leader>th", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
      { "<C-p>", "<cmd>Telescope git_files<CR>", desc = "Git files" },
      { "<leader>s", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<leader>b", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>hh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      local state = require("telescope.state")

      telescope.setup {
        defaults = {
          layout_config = {
            width = 0.95,
            height = 0.95,
            preview_width = 0.55,
          },
        },
        pickers = {},
        extensions = {},
      }

      local last_find_files = nil

      local function find_files(opts)
        opts = opts or {}
        if not last_find_files then
          require("telescope.builtin").find_files {
            attach_mappings = function(prompt_bufnr, map)
              actions.close:enhance {
                post = function()
                  local cached_pickers = state.get_global_key("cached_pickers")
                  if cached_pickers and not vim.tbl_isempty(cached_pickers) then
                    last_find_files = cached_pickers[1]
                  else
                    print("No picker(s) cached")
                  end
                end
              }
              return true
            end
          }
        else
          require("telescope.builtin").resume { picker = last_find_files }
        end
      end

      -- Expose custom function to lazy keymaps
      _G.my_telescope = { find_files = find_files }
    end,
  },
}

