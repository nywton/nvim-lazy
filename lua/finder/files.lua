-- File finder: rg lists candidates, fzf filters them and previews the file
-- under the cursor, both external CLI tools (not vim plugins) run inside a
-- centered floating window (finder.picker). Replaces telescope's
-- find_files/git_files.
local picker = require("finder.picker")
local M = {}

function M.find_files()
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  if vim.v.shell_error ~= 0 then root = vim.fn.getcwd() end

  local tmpfile = vim.fn.tempname()
  local cmd = string.format(
    "cd %s && rg --files --hidden --glob '!.git' | fzf --preview 'cat -n -- {}' > %s",
    vim.fn.shellescape(root), vim.fn.shellescape(tmpfile)
  )

  picker.open(cmd, function()
    local lines = vim.fn.filereadable(tmpfile) == 1 and vim.fn.readfile(tmpfile) or {}
    vim.fn.delete(tmpfile)
    if lines[1] and lines[1] ~= "" then
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. lines[1]))
    end
  end)
end

return M
