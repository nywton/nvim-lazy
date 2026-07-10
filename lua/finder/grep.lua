-- Content search via ripgrep. live_grep() populates the quickfix list (see
-- <C-k>/<C-j> in core/keymaps/navigation.lua) for prompted searches.
-- goto_word() is the interactive rg+fzf picker used as the no-LSP fallback
-- for gd/gi/gr (core/keymaps/navigation.lua) — ripgrep does the searching,
-- fzf does the picking, both bare external CLI tools, no ctags. Without a
-- language server there's no way to distinguish "definition" from
-- "implementation" from "references", so all three fall back to the same
-- "find occurrences of this word" picker.
local M = {}

function M.live_grep()
  local pattern = vim.fn.input("Grep> ")
  if pattern == "" then return end
  vim.cmd("silent grep! " .. vim.fn.shellescape(pattern))
  vim.cmd("copen")
end

function M.goto_word()
  local word = vim.fn.expand("<cword>")
  if word == "" then return end

  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  if vim.v.shell_error ~= 0 then root = vim.fn.getcwd() end

  local tmpfile = vim.fn.tempname()
  vim.cmd("botright new")
  vim.fn.jobstart(
    string.format(
      "cd %s && rg --line-number --column --no-heading --color=never --hidden --glob '!.git' -w %s | fzf --delimiter=: --nth=4.. > %s",
      vim.fn.shellescape(root), vim.fn.shellescape(word), vim.fn.shellescape(tmpfile)
    ),
    {
      term = true,
      on_exit = function()
        vim.cmd("bd!")
        local lines = vim.fn.filereadable(tmpfile) == 1 and vim.fn.readfile(tmpfile) or {}
        vim.fn.delete(tmpfile)
        local choice = lines[1]
        if not choice or choice == "" then
          return
        end

        local file, lnum, col = choice:match("^(.-):(%d+):(%d+):")
        if not file then
          return
        end

        vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. file))
        vim.api.nvim_win_set_cursor(0, { tonumber(lnum), math.max(tonumber(col) - 1, 0) })
        vim.cmd("normal! zz")
      end,
    }
  )
  vim.cmd("startinsert")
end

return M
