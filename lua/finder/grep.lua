-- Content search via ripgrep, rendered through finder.picker's centered
-- floating window with a real, treesitter-highlighted preview pane
-- (finder.preview, telescope-style). No vim plugins: rg searches, fzf
-- filters/picks.
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

-- --preview command for a "file:lnum:col:..." fzf line (--delimiter=:) that
-- refreshes finder.preview's real buffer, paired with --preview-window 0 to
-- keep fzf's own preview pane invisible (finder.preview's floating window
-- is the one actually shown). Deliberately a --preview, not a `focus` bind:
-- `focus` only fires on cursor movement or fzf's own fuzzy-filtering, not
-- on `reload` (as live_grep uses on every keystroke), so with `focus` the
-- pane would go stale the moment you typed a query. --preview re-runs for
-- the current line on every list update, reload included. word_b64, if
-- non-empty, is a fixed base64 blob (baked in at command-build time)
-- highlighting a known search word in the previewed line, e.g. for
-- goto_word.
local function preview_cmd(word_b64)
  return string.format(
    [[nvim --server $NVIM --remote-expr "v:lua.require(\"finder.preview\").show_match_b64(\"$(printf %%s {1} | base64 -w0)\",\"$(printf %%s {2})\",\"$(printf %%s {3})\",\"%s\")" >/dev/null 2>&1]],
    word_b64 or ""
  )
end

function M.live_grep()
  local root = root_dir()
  local tmpfile = vim.fn.tempname()
  local rg = "rg --line-number --column --no-heading --color=never --hidden --glob '!.git' -- {q}"
  local cmd = string.format(
    "cd %s && : | fzf --disabled --query '' --bind 'start:reload:%s' --bind 'change:reload:%s || true' "
      .. "--delimiter=: --preview %s --preview-window 0 > %s",
    vim.fn.shellescape(root), rg, rg, vim.fn.shellescape(preview_cmd()), vim.fn.shellescape(tmpfile)
  )

  picker.open(cmd, root, function()
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
      .. "fzf --delimiter=: --nth=4.. --preview %s --preview-window 0 > %s",
    vim.fn.shellescape(root), vim.fn.shellescape(word),
    vim.fn.shellescape(preview_cmd(vim.base64.encode(word))), vim.fn.shellescape(tmpfile)
  )

  picker.open(cmd, root, function()
    local lines = vim.fn.filereadable(tmpfile) == 1 and vim.fn.readfile(tmpfile) or {}
    vim.fn.delete(tmpfile)
    open_match(root, lines[1])
  end)
end

return M
