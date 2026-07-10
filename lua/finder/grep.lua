-- Content search via ripgrep, all rendered through finder.picker's centered
-- floating window with a live fzf preview pane (telescope-style). No vim
-- plugins: rg searches, fzf filters/picks/previews.
--
-- live_grep() is interactive: fzf reloads ripgrep on every keystroke (the
-- standard fzf "live grep" recipe) instead of prompting once via input()
-- and dumping into the quickfix list.
-- goto_word() is the interactive rg+fzf picker used as the no-LSP fallback
-- for gd/gi/gr (core/keymaps/navigation.lua) — ripgrep does the searching,
-- fzf does the picking, both bare external CLI tools, no ctags. Without a
-- language server there's no way to distinguish "definition" from
-- "implementation" from "references", so all three fall back to the same
-- "find occurrences of this word" picker.
local picker = require("finder.picker")
local M = {}

-- Shared by live_grep/goto_word: rg output is "file:lnum:col:content", so
-- open the file and land on the exact line/col fzf's cursor was on.
local function open_match(root, choice)
  if not choice or choice == "" then return end

  local file, lnum, col = choice:match("^(.-):(%d+):(%d+):")
  if not file then return end

  vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. file))
  vim.api.nvim_win_set_cursor(0, { tonumber(lnum), math.max(tonumber(col) - 1, 0) })
  vim.cmd("normal! zz")
end

local function root_dir()
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  if vim.v.shell_error ~= 0 then root = vim.fn.getcwd() end
  return root
end

function M.live_grep()
  local root = root_dir()
  local tmpfile = vim.fn.tempname()
  local rg = "rg --line-number --column --no-heading --color=never --hidden --glob '!.git' -- {q}"
  local cmd = string.format(
    "cd %s && : | fzf --disabled --query '' --bind 'start:reload:%s' --bind 'change:reload:%s || true' "
      .. "--delimiter=: --preview 'cat -n -- {1}' --preview-window '+{2}-/2' > %s",
    vim.fn.shellescape(root), rg, rg, vim.fn.shellescape(tmpfile)
  )

  picker.open(cmd, function()
    local lines = vim.fn.filereadable(tmpfile) == 1 and vim.fn.readfile(tmpfile) or {}
    vim.fn.delete(tmpfile)
    open_match(root, lines[1])
  end)
end

function M.goto_word()
  local word = vim.fn.expand("<cword>")
  if word == "" then return end

  local root = root_dir()
  local tmpfile = vim.fn.tempname()
  local cmd = string.format(
    "cd %s && rg --line-number --column --no-heading --color=never --hidden --glob '!.git' -w %s | "
      .. "fzf --delimiter=: --nth=4.. --preview 'cat -n -- {1}' --preview-window '+{2}-/2' > %s",
    vim.fn.shellescape(root), vim.fn.shellescape(word), vim.fn.shellescape(tmpfile)
  )

  picker.open(cmd, function()
    local lines = vim.fn.filereadable(tmpfile) == 1 and vim.fn.readfile(tmpfile) or {}
    vim.fn.delete(tmpfile)
    open_match(root, lines[1])
  end)
end

return M
