-- File finder: rg lists candidates, fzf filters them; the file under the
-- cursor is shown in finder.preview's real, treesitter-highlighted buffer
-- (see its header comment for how the --preview->remote-expr wiring works),
-- both run inside a centered floating window (finder.picker). Replaces
-- telescope's find_files/git_files.
local picker = require("finder.picker")
local M = {}

function M.find_files()
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  if vim.v.shell_error ~= 0 then root = vim.fn.getcwd() end

  local tmpfile = vim.fn.tempname()
  -- A real --preview (not a `focus` bind) is what re-runs on every list
  -- update, not just cursor movement — see finder.grep's preview_cmd
  -- comment for why that distinction matters. --preview-window 0 keeps
  -- fzf's own preview pane invisible; finder.preview's floating window is
  -- the one actually shown.
  local preview_cmd = [[nvim --server $NVIM --remote-expr "v:lua.require(\"finder.preview\").show_file_b64(\"$(printf %s {} | base64 -w0)\")" >/dev/null 2>&1]]
  local cmd = string.format(
    "cd %s && rg --files --hidden --glob '!.git' | fzf --preview %s --preview-window 0 > %s",
    vim.fn.shellescape(root), vim.fn.shellescape(preview_cmd), vim.fn.shellescape(tmpfile)
  )

  picker.open(cmd, root, function()
    local lines = vim.fn.filereadable(tmpfile) == 1 and vim.fn.readfile(tmpfile) or {}
    vim.fn.delete(tmpfile)
    if lines[1] and lines[1] ~= "" then
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. lines[1]))
    end
  end)
end

return M
