-- Repo-wide diff review: cycle every changed file (working tree vs HEAD) in
-- a side-by-side, syntax-highlighted diff and stage hunks into the index as
-- you go, without leaving the view. Same floating-pane language as
-- git.status/finder.picker (centered, rounded, list-on-the-left), and the
-- list itself reuses git.commands' Staged/Unstaged/Untracked grouping so
-- staging a hunk visibly moves the file between sections in real time —
-- this is git.status's picker with a real side-by-side diff (and hunk-level
-- accept) standing in for its terminal word-diff preview.
--
-- On-demand only (<leader>gr) — starting Neovim to edit a file must never
-- drop you into a review session.
local diffsplit = require("git.diffsplit")
local gitcmd = require("git.commands")
local M = {}

local S = {
  active = false,
  root = nil,
  files = {}, -- ordered, stable list of relpaths (strings) for the session
  idx = 0,
  origin_win = nil,
  list_win = nil,
  list_buf = nil,
  left_win = nil,
  right_win = nil,
  ns = vim.api.nvim_create_namespace("git_review"),
}

-- `git status --short` reports exactly the set we want: staged, unstaged
-- and untracked, one line per file (renames as "R  old -> new").
local function changed_files(root)
  local out = vim.fn.systemlist({ "git", "-C", root, "status", "--short" })
  local files, seen = {}, {}
  for _, line in ipairs(out) do
    local file = line:match(" %-> (.+)$") or line:sub(4)
    if file ~= "" and not seen[file] then
      seen[file] = true
      table.insert(files, file)
    end
  end
  table.sort(files)
  return files
end

-- Fresh status codes for the list's live Staged/Unstaged grouping — unlike
-- `has_head_version` below, staging *does* change this from one render to
-- the next, so it's re-fetched on every render_list() call.
local function status_map()
  local out = vim.fn.systemlist({ "git", "-C", S.root, "status", "--short" })
  local map = {}
  for _, line in ipairs(out) do
    local file = line:match(" %-> (.+)$") or line:sub(4)
    if file ~= "" then map[file] = line:sub(1, 2) end
  end
  return map
end

-- Whether `file` exists in HEAD at all — false for anything `git add`
-- hasn't touched yet *and* anything added-but-not-committed, both of which
-- need the "whole file" accept path since there's no HEAD blob to diff
-- against. Unlike the status code, this is invariant for the whole review
-- session (HEAD doesn't move), so it's safe to call on demand everywhere.
local function has_head_version(file)
  vim.fn.system({ "git", "-C", S.root, "cat-file", "-e", "HEAD:" .. file })
  return vim.v.shell_error == 0
end

-- ---------------------------------------------------------------------
-- Hunk staging: parse `git diff --unified=3 HEAD -- file` ourselves (same
-- text git-apply consumes) rather than trusting Neovim's own diffthis
-- rendering to line up 1:1 with git's — both use myers by default so they
-- usually agree, but staging has to be exact, so it goes straight to git's
-- own diff output instead of reverse-engineering it from `diff_hlID`.
-- ---------------------------------------------------------------------

local function parse_hunks(diff_lines)
  local header, hunks, cur = {}, {}, nil
  for _, line in ipairs(diff_lines) do
    local new_start, new_count = line:match("^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
    if new_start then
      cur = { new_start = tonumber(new_start), new_count = new_count ~= "" and tonumber(new_count) or 1, lines = { line } }
      table.insert(hunks, cur)
    elseif cur then
      table.insert(cur.lines, line)
    else
      table.insert(header, line)
    end
  end
  return header, hunks
end

-- Returns (header, hunks) — matches parse_hunks' order.
local function file_hunks(file)
  if not has_head_version(file) then return {}, {} end
  local diff_out = vim.fn.systemlist({ "git", "-C", S.root, "diff", "--unified=3", "HEAD", "--", file })
  return parse_hunks(diff_out)
end

-- The hunk whose new-file range contains `lnum`, else the nearest one —
-- same "closest hunk to cursor" heuristic gitsigns-style stage-hunk uses.
local function nearest_hunk(hunks, lnum)
  local best, best_dist
  for _, h in ipairs(hunks) do
    local lo, hi = h.new_start, h.new_start + math.max(h.new_count - 1, 0)
    local dist = (lnum >= lo and lnum <= hi) and 0 or math.min(math.abs(lnum - lo), math.abs(lnum - hi))
    if not best or dist < best_dist then
      best, best_dist = h, dist
    end
  end
  return best
end

-- ---------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------

-- Renders the same Conflicted/Staged/Unstaged/Untracked grouping as
-- git.status (git/commands.lua's classify()/SECTION_ORDER), so accepting a
-- hunk that fully stages a file visibly moves it from Unstaged into Staged
-- here, live. S.idx stays a stable index into S.files regardless of how
-- entries are grouped; a file straddling two sections (partially staged)
-- gets the "current" marker in both.
local function render_list()
  local codes = status_map()
  local buckets = {}
  for _, section in ipairs(gitcmd.SECTION_ORDER) do
    buckets[section] = {}
  end
  for i, file in ipairs(S.files) do
    local code = codes[file] or "  "
    for _, section in ipairs(gitcmd.classify(code)) do
      table.insert(buckets[section], { i = i, file = file })
    end
  end

  local lines, header_lines, current_lines = {}, {}, {}
  for _, section in ipairs(gitcmd.SECTION_ORDER) do
    local items = buckets[section]
    if #items > 0 then
      table.insert(lines, string.format("%s (%d)", section, #items))
      header_lines[#lines] = true
      for _, item in ipairs(items) do
        local marker = item.i == S.idx and "\226\150\184 " or "  "
        table.insert(lines, marker .. item.file)
        if item.i == S.idx then table.insert(current_lines, #lines) end
      end
      table.insert(lines, "")
    end
  end
  if #lines > 0 then table.remove(lines) end
  table.insert(lines, "")
  table.insert(lines, "gs stage hunk \226\128\162 C-n/C-p file/hunk \226\128\162 q quit")

  vim.bo[S.list_buf].modifiable = true
  vim.api.nvim_buf_set_lines(S.list_buf, 0, -1, false, lines)
  vim.bo[S.list_buf].modifiable = false
  vim.bo[S.list_buf].modified = false

  vim.api.nvim_buf_clear_namespace(S.list_buf, S.ns, 0, -1)
  for _, hl_lnum in ipairs(current_lines) do
    vim.api.nvim_buf_set_extmark(S.list_buf, S.ns, hl_lnum - 1, 0, { end_col = #lines[hl_lnum], hl_group = "PmenuSel" })
  end
  for lnum in pairs(header_lines) do
    vim.api.nvim_buf_set_extmark(S.list_buf, S.ns, lnum - 1, 0, { end_col = #lines[lnum], hl_group = "Title" })
  end
  vim.api.nvim_buf_set_extmark(S.list_buf, S.ns, #lines - 1, 0, { end_col = #lines[#lines], hl_group = "Comment" })
  if current_lines[1] then
    pcall(vim.api.nvim_win_set_cursor, S.list_win, { current_lines[1], 0 })
  end
end

-- buffer-local so the mappings live and die with the review's own buffers
-- and never shadow <C-n>/<C-p>/<leader>gs/q anywhere else in the editor.
local function bind(buf)
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "<C-n>", M.next, vim.tbl_extend("force", opts, { desc = "Review: next hunk, then next file" }))
  vim.keymap.set("n", "<C-p>", M.prev, vim.tbl_extend("force", opts, { desc = "Review: previous hunk, then previous file" }))
  vim.keymap.set("n", "<leader>gs", M.accept_hunk, vim.tbl_extend("force", opts, { desc = "Review: accept hunk / stage file" }))
  vim.keymap.set("n", "q", M.quit, vim.tbl_extend("force", opts, { desc = "Review: quit" }))
  vim.keymap.set("n", "<Esc>", M.quit, vim.tbl_extend("force", opts, { desc = "Review: quit" }))
end

-- Loads files[idx] into the fixed left/right diff panes: left is the real,
-- editable working-tree buffer (so accept_hunk reads a real cursor line and
-- the file stays genuinely editable), right is HEAD's blob via
-- diffsplit.load_rev. New files (untracked, or staged-but-uncommitted) have
-- no HEAD blob — the right pane says so and accept_hunk falls back to a
-- whole-file `git add`.
local function show_current()
  local file = S.files[S.idx]
  if not file then return end

  vim.api.nvim_win_call(S.left_win, function()
    vim.cmd("edit " .. vim.fn.fnameescape(S.root .. "/" .. file))
    vim.cmd("diffthis")
  end)
  bind(vim.api.nvim_win_get_buf(S.left_win))

  local right_buf
  if has_head_version(file) then
    right_buf = diffsplit.load_rev(S.root, "HEAD", file, vim.bo[vim.api.nvim_win_get_buf(S.left_win)].filetype)
  else
    right_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[right_buf].buftype = "nofile"
    vim.bo[right_buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, { "(new file \226\128\148 no HEAD version)" })
  end
  if right_buf then
    vim.api.nvim_win_set_buf(S.right_win, right_buf)
    vim.api.nvim_win_call(S.right_win, function() vim.cmd("diffthis") end)
    bind(right_buf)
  end

  render_list()
  vim.api.nvim_set_current_win(S.left_win)
end

-- Cursor to the first (forward) or last (backward) hunk of the file just
-- switched to, so a run of C-n/C-p across a file boundary keeps landing
-- squarely on a change instead of on line 1.
local function goto_hunk_edge(forward)
  local _, hunks = file_hunks(S.files[S.idx])
  if #hunks == 0 then return end
  local target = forward and hunks[1] or hunks[#hunks]
  pcall(vim.api.nvim_win_set_cursor, S.left_win, { target.new_start, 0 })
end

-- Step within the current file's hunks first (native ]c/[c — both panes are
-- already in :diffthis), and only cross into the next/previous file once
-- there are no more hunks in that direction. New files have no hunks to
-- step through, so they're always a direct file-to-file jump.
local function step(forward)
  if not S.active or #S.files == 0 then return end

  if has_head_version(S.files[S.idx]) then
    -- ]c/[c at the last/first hunk of the file is a silent no-op, not an
    -- error — pcall's `ok` alone can't tell "moved" from "already at the
    -- edge", so check the cursor actually moved before treating this as a
    -- same-file hunk step.
    local before = vim.api.nvim_win_get_cursor(S.left_win)
    pcall(vim.api.nvim_win_call, S.left_win, function()
      vim.cmd(forward and "normal! ]c" or "normal! [c")
    end)
    local after = vim.api.nvim_win_get_cursor(S.left_win)
    if after[1] ~= before[1] or after[2] ~= before[2] then
      vim.api.nvim_set_current_win(S.left_win)
      return
    end
  end

  S.idx = forward and (S.idx % #S.files + 1) or ((S.idx - 2) % #S.files + 1)
  show_current()
  goto_hunk_edge(forward)
end

function M.next() step(true) end
function M.prev() step(false) end

function M.accept_hunk()
  if not S.active then return end
  local file = S.files[S.idx]
  if not file then return end

  if not has_head_version(file) then
    vim.fn.system({ "git", "-C", S.root, "add", "--", file })
    vim.notify("Staged (new file): " .. file, vim.log.levels.INFO)
    render_list()
    step(true) -- nothing left to do in this file, move on
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(S.left_win)[1]
  local header, hunks = file_hunks(file)
  if #hunks == 0 then
    vim.notify("No hunks left to stage in " .. file, vim.log.levels.INFO)
    return
  end

  local hunk = nearest_hunk(hunks, lnum)
  local patch = table.concat(header, "\n") .. "\n" .. table.concat(hunk.lines, "\n") .. "\n"
  local result = vim.fn.system({ "git", "-C", S.root, "apply", "--cached", "--whitespace=nowarn", "-" }, patch)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to stage hunk (already staged?): " .. vim.trim(result), vim.log.levels.ERROR)
  else
    vim.notify(string.format("Staged hunk @@ +%d,%d @@ in %s", hunk.new_start, hunk.new_count, file), vim.log.levels.INFO)
    render_list()
    -- Staging doesn't change working-tree-vs-HEAD content, so the same
    -- hunk boundaries still exist in the diff — ]c genuinely lands on the
    -- *next* hunk here, not a stale one.
    step(true)
  end
end

function M.quit()
  if not S.active then return end
  S.active = false
  for _, win in ipairs({ S.list_win, S.left_win, S.right_win }) do
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  if S.origin_win and vim.api.nvim_win_is_valid(S.origin_win) then
    vim.api.nvim_set_current_win(S.origin_win)
  end
  S.root, S.files, S.idx, S.origin_win, S.list_win, S.list_buf, S.left_win, S.right_win = nil, {}, 0, nil, nil, nil, nil, nil
end

function M.start()
  if S.active then
    vim.notify("Review already active \226\128\148 C-n/C-p to navigate, q to quit", vim.log.levels.INFO)
    return
  end

  local root = diffsplit.git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end

  local files = changed_files(root)
  if #files == 0 then
    vim.notify("No changes to review", vim.log.levels.INFO)
    return
  end

  S.root, S.files, S.idx = root, files, 1
  S.origin_win = vim.api.nvim_get_current_win()

  local width = math.floor(vim.o.columns * 0.94)
  local height = math.floor(vim.o.lines * 0.88)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local list_width = math.max(28, math.floor(width * 0.18))
  local gap = 2
  local diff_width = math.floor((width - list_width - 2 * gap) / 2)

  S.list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[S.list_buf].buftype = "nofile"
  vim.bo[S.list_buf].bufhidden = "wipe"
  S.list_win = vim.api.nvim_open_win(S.list_buf, true, {
    relative = "editor", width = list_width, height = height, row = row, col = col,
    style = "minimal", border = "rounded", title = " changed files ", title_pos = "center",
  })
  vim.wo[S.list_win].cursorline = true
  bind(S.list_buf)

  -- Placeholder buffers, replaced the instant show_current() runs below;
  -- bufhidden=wipe keeps that swap from leaking an empty buffer per pane.
  local left_buf = vim.api.nvim_create_buf(true, false)
  vim.bo[left_buf].bufhidden = "wipe"
  S.left_win = vim.api.nvim_open_win(left_buf, false, {
    relative = "editor", width = diff_width, height = height, row = row, col = col + list_width + gap,
    style = "minimal", border = "rounded", title = " working tree ", title_pos = "center",
  })
  vim.wo[S.left_win].wrap = false

  local right_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[right_buf].bufhidden = "wipe"
  S.right_win = vim.api.nvim_open_win(right_buf, false, {
    relative = "editor", width = diff_width, height = height, row = row, col = col + list_width + gap + diff_width + gap,
    style = "minimal", border = "rounded", title = " HEAD ", title_pos = "center",
  })
  vim.wo[S.right_win].wrap = false
  diffsplit.style_diff_windows(S.left_win, S.right_win)

  S.active = true

  local function close_on(win)
    vim.api.nvim_create_autocmd("WinClosed", { pattern = tostring(win), once = true, callback = M.quit })
  end
  close_on(S.list_win)
  close_on(S.left_win)
  close_on(S.right_win)

  show_current()
end

return M
