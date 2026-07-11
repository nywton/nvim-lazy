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

-- Same as scratch(), but reformats diff/log -p output the way delta does:
-- one label line per file instead of the diff --git/index/---/+++ block,
-- hunk headers reduced to line number + function context, +/- lines with a
-- full-line background. See git/delta.lua. No filetype set — that raw
-- 'diff'/'git' syntax would fight the extmarks delta.lua paints on top of
-- the rewritten lines.
local function delta_scratch(cmd, name)
  local out = vim.fn.systemlist(cmd)
  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  require("git.delta").render_to_buffer(buf, out)
  if name then pcall(vim.api.nvim_buf_set_name, buf, name) end
  return buf
end

-- Diff command for the status preview pane, run inside a terminal buffer
-- (not a plain scratch one) so --word-diff=color's ANSI output — the
-- intra-line word highlighting git itself computes — renders as real
-- colors instead of raw escape codes. Untracked files have nothing to diff
-- against in the index/HEAD, so compare against /dev/null; everything else
-- diffs straight against HEAD (covers staged + unstaged in one call — same
-- approach as git/signs.lua).
local function preview_diff_cmd(root, code, file)
  if code:sub(1, 1) == "?" then
    return { "git", "-C", root, "diff", "--no-index", "--color=always", "--word-diff=color", "--", "/dev/null", file }
  end
  return { "git", "-C", root, "diff", "HEAD", "--color=always", "--word-diff=color", "--", file }
end

-- Fugitive-style section grouping for the status list. A file can land in
-- BOTH Staged and Unstaged (e.g. "MM": staged, then modified again) — real
-- git semantics, so it gets one entry per section, not just one overall.
local SECTION_ORDER = { "Conflicted", "Staged", "Unstaged", "Untracked" }
local CONFLICT_CODES = {
  DD = true, AU = true, UD = true, UA = true, DU = true, AA = true, UU = true,
}

local function classify(code)
  if CONFLICT_CODES[code] then
    return { "Conflicted" }
  end
  if code:sub(1, 1) == "?" then
    return { "Untracked" }
  end
  local sections = {}
  if code:sub(1, 1) ~= " " then table.insert(sections, "Staged") end
  if code:sub(2, 2) ~= " " then table.insert(sections, "Unstaged") end
  return sections
end

-- Exposed for git.review: it renders the same section-grouped file list
-- (so staging a hunk visibly moves a file between Unstaged/Staged there
-- too) instead of duplicating this classification.
M.SECTION_ORDER = SECTION_ORDER
M.classify = classify

-- Floating, centered status picker with a live diff preview — the git
-- equivalent of telescope's git_status. No plugin: two floating windows
-- (a scratch list + a terminal buffer replaced on every CursorMoved).
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
  vim.bo[preview_buf].bufhidden = "wipe"

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
  local header_ns = vim.api.nvim_create_namespace("git_status_headers")

  local function set_lines(buf, lines)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
  end

  -- Renders "Section (N)" headers (bold, like fugitive) followed by its
  -- entries and a blank separator. entries[lnum] stays nil for header/blank
  -- lines, which every other function here already treats as "no file".
  local function load_entries()
    local out = vim.fn.systemlist({ "git", "-C", root, "status", "--short" })
    local buckets = { Conflicted = {}, Staged = {}, Unstaged = {}, Untracked = {} }
    for _, line in ipairs(out) do
      local code, file = line:sub(1, 2), line:sub(4)
      for _, section in ipairs(classify(code)) do
        table.insert(buckets[section], { code = code, file = file, section = section })
      end
    end

    entries = {}
    local rendered = {}
    local header_lines = {}
    for _, section in ipairs(SECTION_ORDER) do
      local items = buckets[section]
      if #items > 0 then
        table.insert(rendered, string.format("%s (%d)", section, #items))
        header_lines[#rendered] = true
        for _, item in ipairs(items) do
          table.insert(rendered, string.format("  %s %s", item.code, item.file))
          entries[#rendered] = item
        end
        table.insert(rendered, "")
      end
    end
    if #rendered > 0 then
      table.remove(rendered) -- drop the trailing blank separator
    else
      rendered = { "(clean)" }
    end

    set_lines(list_buf, rendered)
    vim.api.nvim_buf_clear_namespace(list_buf, header_ns, 0, -1)
    for lnum in pairs(header_lines) do
      vim.api.nvim_buf_set_extmark(list_buf, header_ns, lnum - 1, 0, {
        end_col = #rendered[lnum],
        hl_group = "Title",
      })
    end
  end

  local function update_preview()
    if not vim.api.nvim_win_is_valid(list_win) or not vim.api.nvim_win_is_valid(preview_win) then
      return
    end
    local lnum = vim.api.nvim_win_get_cursor(list_win)[1]
    local entry = entries[lnum]

    -- A fresh buffer per refresh: a terminal buffer is inert once its job
    -- exits, so "updating" the preview means swapping in a new one rather
    -- than rewriting lines. bufhidden=wipe cleans up the old one the moment
    -- it stops being displayed (right after nvim_win_set_buf below).
    local new_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[new_buf].bufhidden = "wipe"
    vim.api.nvim_win_set_buf(preview_win, new_buf)

    -- Git's default ANSI green (word-diff's "added" color) is a fully
    -- saturated #00cd00-ish green — fine for a few highlighted words in a
    -- normal diff, but an untracked file is 100% "added", so the whole pane
    -- turns into a wall of bright green. b:terminal_color_2 is read once at
    -- TermOpen (see :h terminal-config), so it must be set before jobstart
    -- below; toning it down here matches the muted green diffsplit.lua uses
    -- for the same "added" concept elsewhere in git.* previews.
    vim.b[new_buf].terminal_color_2 = "#4d9a6a"

    if entry then
      local cur_win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_current_win(preview_win)
      vim.fn.jobstart(preview_diff_cmd(root, entry.code, entry.file), { term = true })
      vim.api.nvim_set_current_win(cur_win)
    else
      vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, { "(clean)" })
    end
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
    if not entry then
      return
    end
    -- Smart toggle: unstage a Staged entry, stage anything else
    -- (Unstaged/Untracked/Conflicted — `git add` also resolves a conflict
    -- once you've hand-edited out the markers, matching plain git usage).
    if entry.section == "Staged" then
      vim.fn.system({ "git", "-C", root, "restore", "--staged", "--", entry.file })
    else
      vim.fn.system({ "git", "-C", root, "add", "--", entry.file })
    end
    load_entries()
    update_preview()
  end, "Stage/unstage file (toggle)")
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
  delta_scratch("git -C " .. vim.fn.shellescape(root) .. " diff " .. (target or ""), "git-diff")
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

-- Full-patch (-p) log, capped at 200 commits like the old --oneline overview
-- was, since -p output is a lot bigger per commit. Repo-wide flat scratch
-- view — for a navigable per-commit/per-file browser see git.history
-- (<leader>gl).
function M.log_repo()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  delta_scratch("git -C " .. vim.fn.shellescape(root) .. " log -p -n 200", "git-log")
end

function M.stage_file()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  vim.fn.system({ "git", "-C", root, "add", "--", vim.fn.expand("%:p") })
  vim.notify("Staged " .. vim.fn.expand("%:."), vim.log.levels.INFO)
end

function M.unstage_file()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  vim.fn.system({ "git", "-C", root, "restore", "--staged", "--", vim.fn.expand("%:p") })
  vim.notify("Unstaged " .. vim.fn.expand("%:."), vim.log.levels.INFO)
end

-- Interactive (needs $EDITOR / credentials) — a real terminal, not a wrapper.
function M.commit()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  vim.cmd("vnew | terminal git -C " .. vim.fn.shellescape(root) .. " commit")
  vim.cmd("startinsert")
end

function M.push()
  local root = git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  vim.cmd("vnew | terminal git -C " .. vim.fn.shellescape(root) .. " push")
  vim.cmd("startinsert")
end

return M
