-- Side-by-side git diff with syntax highlighting, built entirely from
-- Neovim's own diff engine (:diffthis) plus filetype/treesitter
-- highlighting — no delta binary, no diffview/fugitive. `git show` supplies
-- the other revision's content, fzf (git log + branches) picks which
-- revision, Neovim does the alignment, coloring and scroll/cursor binding.
local M = {}

local function git_root()
  local root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  return vim.v.shell_error == 0 and root or nil
end
M.git_root = git_root

-- Same recipe as finder.preview: filetype triggers legacy :syntax
-- highlighting (always available), treesitter layers on top of it when a
-- parser happens to be installed — pcall makes that purely optional, this
-- config ships none by default.
local function highlight(buf, ft)
  vim.bo[buf].filetype = ft or ""
  if ft and ft ~= "" then
    local lang = vim.treesitter.language.get_lang(ft) or ft
    pcall(vim.treesitter.start, buf, lang)
  end
end

-- GitHub/VSCode-style diff coloring: green for genuinely new content, red
-- for content that's gone relative to HEAD, and fully transparent for
-- filler (alignment padding — there's no real content there, so painting a
-- solid block over it fights the transparent background for no reason).
--
-- Vim's diff groups are direction-agnostic — DiffAdd just means "this
-- window has extra content here", regardless of which window. M.split and
-- git.review always put the working tree on the left and the older
-- revision on the right, so winhighlight remaps the groups per-window
-- instead of recoloring DiffAdd/DiffChange/DiffText globally: left reads
-- green, right reads red. DiffChange maps to the same color as DiffAdd on
-- each side (a "changed" line really is just an old line gone + a new line
-- added), with DiffText — the exact differing text within it — a stronger
-- shade of the same color, mirroring GitHub's word-level highlight.
local hl_defined = false
local function define_diff_highlights()
  if hl_defined then return end
  hl_defined = true
  vim.api.nvim_set_hl(0, "DiffviewAddNew", { bg = "#0f3823" })
  vim.api.nvim_set_hl(0, "DiffviewTextNew", { bg = "#1f6b3f" })
  vim.api.nvim_set_hl(0, "DiffviewAddOld", { bg = "#3b1219" })
  vim.api.nvim_set_hl(0, "DiffviewTextOld", { bg = "#6e1f28" })
  vim.api.nvim_set_hl(0, "DiffviewFiller", { bg = "NONE" })
end

-- `new_win` (working tree) gets green additions, `old_win` (the older
-- revision) gets red — see define_diff_highlights() above.
function M.style_diff_windows(new_win, old_win)
  define_diff_highlights()
  vim.wo[new_win].winhighlight =
    "DiffAdd:DiffviewAddNew,DiffChange:DiffviewAddNew,DiffText:DiffviewTextNew,DiffDelete:DiffviewFiller"
  vim.wo[old_win].winhighlight =
    "DiffAdd:DiffviewAddOld,DiffChange:DiffviewAddOld,DiffText:DiffviewTextOld,DiffDelete:DiffviewFiller"
end

local function load_rev(root, rev, relpath, ft)
  local out = vim.fn.systemlist({ "git", "-C", root, "show", rev .. ":" .. relpath })
  if vim.v.shell_error ~= 0 then
    vim.notify(string.format("git show %s:%s failed", rev, relpath), vim.log.levels.ERROR)
    return nil
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].modified = false
  pcall(vim.api.nvim_buf_set_name, buf, string.format("diff://%s/%s#%d", rev, relpath, buf))
  highlight(buf, ft)
  return buf
end
M.load_rev = load_rev

-- Left = working tree (current buffer, untouched). Right = `rev` (a scratch
-- buffer). Defaults to HEAD — same comparison git/signs.lua and the status
-- preview already use for "what's changed here".
function M.split(rev)
  rev = (rev and rev ~= "") and rev or "HEAD"
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end
  local relpath = file:sub(#root + 2)

  local right_buf = load_rev(root, rev, relpath, vim.bo.filetype)
  if not right_buf then return end

  local left_win = vim.api.nvim_get_current_win()
  vim.cmd("diffthis")

  vim.cmd("vsplit")
  local right_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_win, right_buf)
  vim.cmd("diffthis")

  M.style_diff_windows(left_win, right_win)
  vim.api.nvim_set_current_win(left_win)
end

function M.close()
  vim.cmd("diffoff!")
end

-- fzf-driven revision picker: local branches + recent commits of the whole
-- repo, piped through fzf in a small floating terminal. Single-pane (unlike
-- finder.picker's list+preview layout) — there's no natural file-content
-- preview for "which commit", the diff split itself becomes the preview.
function M.pick()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  if vim.api.nvim_buf_get_name(0) == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local tmpfile = vim.fn.tempname()
  local refs = string.format(
    "{ git -C %s branch --format='%%(refname:short)'; git -C %s log --oneline -n 200; }",
    vim.fn.shellescape(root), vim.fn.shellescape(root)
  )
  local cmd = string.format(
    "%s | fzf --prompt='diff against> ' > %s",
    refs, vim.fn.shellescape(tmpfile)
  )

  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.5)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " diff against ",
    title_pos = "center",
  })

  local function close_picker()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end

  vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      close_picker()
      local lines = vim.fn.filereadable(tmpfile) == 1 and vim.fn.readfile(tmpfile) or {}
      vim.fn.delete(tmpfile)
      local choice = lines[1]
      if not choice or choice == "" then return end
      M.split((choice:match("^(%S+)")))
    end,
  })
  vim.keymap.set("t", "<Esc>", close_picker, { buffer = buf, nowait = true })
  vim.cmd("startinsert")
end

return M
