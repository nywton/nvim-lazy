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

-- Diff shown in the status preview pane for one entry: untracked files have
-- nothing to diff against in the index/HEAD, so compare against /dev/null;
-- everything else diffs straight against HEAD (covers staged + unstaged in
-- one call — same approach as git/signs.lua).
local function preview_diff(root, code, file)
  if code:sub(1, 1) == "?" then
    return vim.fn.systemlist({ "git", "-C", root, "diff", "--no-index", "--", "/dev/null", file })
  end
  return vim.fn.systemlist({ "git", "-C", root, "diff", "HEAD", "--", file })
end

-- Floating, centered status picker with a live diff preview — the git
-- equivalent of telescope's git_status. No plugin: two floating scratch
-- windows (list + preview), the preview re-rendered on CursorMoved and
-- highlighted with the `diff` Treesitter parser (core/treesitter_parsers.lua).
function M.status()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end

  local origin_win = vim.api.nvim_get_current_win()

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local list_width = math.floor(width * 0.35)
  local preview_width = width - list_width - 2

  local list_buf = vim.api.nvim_create_buf(false, true)
  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[list_buf].buftype = "nofile"
  vim.bo[list_buf].bufhidden = "wipe"
  vim.bo[preview_buf].buftype = "nofile"
  vim.bo[preview_buf].bufhidden = "wipe"
  vim.bo[preview_buf].filetype = "diff"

  local list_win = vim.api.nvim_open_win(list_buf, true, {
    relative = "editor",
    width = list_width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " git status ",
    title_pos = "center",
  })
  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = "editor",
    width = preview_width,
    height = height,
    row = row,
    col = col + list_width + 2,
    style = "minimal",
    border = "rounded",
    title = " diff ",
    title_pos = "center",
  })
  vim.wo[preview_win].wrap = false

  local entries = {}

  local function set_lines(buf, lines)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
  end

  local function load_entries()
    local out = vim.fn.systemlist({ "git", "-C", root, "status", "--short" })
    entries = {}
    for _, line in ipairs(out) do
      table.insert(entries, { code = line:sub(1, 2), file = line:sub(4) })
    end
    set_lines(list_buf, #out > 0 and out or { "(clean)" })
  end

  local function update_preview()
    if not vim.api.nvim_win_is_valid(list_win) then
      return
    end
    local lnum = vim.api.nvim_win_get_cursor(list_win)[1]
    local entry = entries[lnum]
    local diff_lines = entry and preview_diff(root, entry.code, entry.file) or {}
    set_lines(preview_buf, #diff_lines > 0 and diff_lines or { entry and "(no diff)" or "" })
    pcall(vim.treesitter.start, preview_buf, "diff")
  end

  load_entries()
  update_preview()

  local function close()
    for _, w in ipairs({ list_win, preview_win }) do
      if vim.api.nvim_win_is_valid(w) then
        vim.api.nvim_win_close(w, true)
      end
    end
  end

  vim.api.nvim_create_autocmd("CursorMoved", { buffer = list_buf, callback = update_preview })
  vim.api.nvim_create_autocmd("WinClosed", {
    once = true,
    pattern = tostring(list_win),
    callback = close,
  })

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = list_buf, desc = desc, nowait = true })
  end

  map("q", close, "Close git status")
  map("<Esc>", close, "Close git status")
  map("<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(list_win)[1]
    local entry = entries[lnum]
    close()
    if entry then
      vim.api.nvim_set_current_win(origin_win)
      vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. entry.file))
    end
  end, "Open file")
  map("s", function()
    local entry = entries[vim.api.nvim_win_get_cursor(list_win)[1]]
    if entry then
      vim.fn.system({ "git", "-C", root, "add", "--", entry.file })
      load_entries()
      update_preview()
    end
  end, "Stage file")
  map("u", function()
    local entry = entries[vim.api.nvim_win_get_cursor(list_win)[1]]
    if entry then
      vim.fn.system({ "git", "-C", root, "restore", "--staged", "--", entry.file })
      load_entries()
      update_preview()
    end
  end, "Unstage file")
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
