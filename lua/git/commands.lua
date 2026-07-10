-- Raw `git` + scratch buffers, replacing vim-fugitive/diffview.nvim.
-- Deliberately not full fugitive parity: no inline hunk staging from the
-- diff view, no merge-conflict helpers beyond plain Vim diff-mode (see
-- <leader>g1/<leader>g2 in git/keymaps.lua). For anything interactive/
-- stateful (commit, push, pull, rebase) use the terminal (lua/terminal.lua)
-- directly instead of a wrapper — it already opens $EDITOR correctly.
local M = {}

local function git_root()
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  return vim.v.shell_error == 0 and root or nil
end

local function scratch(cmd, ft, name)
  local out = vim.fn.systemlist(cmd)
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = ft
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].modified = false
  if name then pcall(vim.api.nvim_buf_set_name, buf, name) end
  return buf
end

function M.status()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  local buf = scratch("git -C " .. vim.fn.shellescape(root) .. " status --short", "gitstatus", "git-status")

  vim.keymap.set("n", "<CR>", function()
    local file = vim.api.nvim_get_current_line():match("^..%s(.+)$")
    if file then
      vim.cmd("wincmd p")
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. file))
    end
  end, { buffer = buf, desc = "Open file under cursor" })

  vim.keymap.set("n", "s", function()
    local file = vim.api.nvim_get_current_line():match("^..%s(.+)$")
    if file then
      vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " add -- " .. vim.fn.shellescape(file))
      vim.cmd("bd!")
      M.status()
    end
  end, { buffer = buf, desc = "Stage file" })

  vim.keymap.set("n", "u", function()
    local file = vim.api.nvim_get_current_line():match("^..%s(.+)$")
    if file then
      vim.fn.system("git -C " .. vim.fn.shellescape(root) .. " restore --staged -- " .. vim.fn.shellescape(file))
      vim.cmd("bd!")
      M.status()
    end
  end, { buffer = buf, desc = "Unstage file" })
end

function M.diff(target)
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  scratch("git -C " .. vim.fn.shellescape(root) .. " diff " .. (target or ""), "diff", "git-diff")
end

function M.blame()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  local file = vim.fn.expand("%:.")
  scratch("git -C " .. vim.fn.shellescape(root) .. " blame -- " .. vim.fn.shellescape(file), "git", "git-blame")
end

function M.log()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  scratch("git -C " .. vim.fn.shellescape(root) .. " log --oneline --graph -n 200", "git", "git-log")
end

return M
