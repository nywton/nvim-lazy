-- Repo-wide `git log -p` browser: step through commits and, within each
-- commit, its changed files, in a side-by-side diff (commit's blob on the
-- left, parent's blob on the right) — the git.review floating-pane layout
-- (list-on-the-left, two diff panes) repurposed for history instead of the
-- working tree. Read-only: no staging, no editing.
local diffsplit = require("git.diffsplit")
local M = {}

local S = {
  active = false,
  root = nil,
  commits = {}, -- ordered, newest first: { hash, short, author, date, subject, body, parent, files = { {status, path, old_path} } }
  commit_idx = 0,
  file_idx = 0,
  origin_win = nil,
  list_win = nil,
  list_buf = nil,
  left_win = nil,
  right_win = nil,
  ns = vim.api.nvim_create_namespace("git_history"),
}

local SEP = "\1" -- field separator for the metadata log call below; never appears in git's own output

-- Two `git log` calls rather than one: the metadata fields (%H/%h/%an/%ad/%P/%s)
-- are all guaranteed single-line, so SEP-joining them is unambiguous, but the
-- full commit body (%b) can itself contain blank lines and multi-line text
-- that would collide with --name-status's own blank-line-separated records.
-- Body is instead fetched lazily per commit (ensure_body) only when it's
-- actually shown, which also keeps the upfront cost to two cheap calls
-- regardless of history length.
local function load_commits(root)
  local log_out = vim.fn.systemlist({
    "git", "-C", root, "log", "-n", "200", "--date=short",
    "--format=%H" .. SEP .. "%h" .. SEP .. "%an" .. SEP .. "%ad" .. SEP .. "%P" .. SEP .. "%s",
  })
  local commits, by_hash = {}, {}
  for _, line in ipairs(log_out) do
    local parts = vim.split(line, SEP, { plain = true })
    if #parts == 6 then
      local commit = {
        hash = parts[1], short = parts[2], author = parts[3], date = parts[4],
        parent = vim.split(parts[5], " ", { plain = true })[1] or "",
        subject = parts[6], body = nil, files = {},
      }
      table.insert(commits, commit)
      by_hash[commit.hash] = commit
    end
  end

  local ns_out = vim.fn.systemlist({
    "git", "-C", root, "log", "-n", "200", "--name-status", "--format=" .. SEP .. "%H",
  })
  local cur = nil
  for _, line in ipairs(ns_out) do
    if line:sub(1, 1) == SEP then
      cur = by_hash[line:sub(2)]
    elseif cur and line ~= "" then
      local fields = vim.split(line, "\t", { plain = true })
      local status = fields[1]:sub(1, 1)
      if status == "R" or status == "C" then
        table.insert(cur.files, { status = status, old_path = fields[2], path = fields[3] })
      else
        table.insert(cur.files, { status = status, path = fields[2] })
      end
    end
  end

  return commits
end

-- Guards diffsplit.load_rev against paths `git show` can't render as text:
-- submodule gitlinks (mode 160000) are the main case — `git show rev:path`
-- on one fails outright, and diffsplit.load_rev would vim.notify an ERROR
-- for every single nav step that revisits it. `cat-file -e` cleanly reports
-- "not a blob at this path" without that side effect.
local function safe_load_rev(root, rev, path, ft)
  vim.fn.system({ "git", "-C", root, "cat-file", "-e", rev .. ":" .. path })
  if vim.v.shell_error ~= 0 then return nil end
  return diffsplit.load_rev(root, rev, path, ft)
end

local function ensure_body(root, commit)
  if commit.body then return end
  local out = vim.fn.systemlist({ "git", "-C", root, "show", "-s", "--format=%B", commit.hash })
  commit.body = table.concat(out, "\n")
end

-- ---------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------

local function render_list()
  local commit = S.commits[S.commit_idx]
  if not commit then return end
  ensure_body(S.root, commit)

  local lines, hl, current_lnum = {}, {}, nil
  local function emit(text, group)
    table.insert(lines, text)
    if group then hl[#lines] = group end
  end

  emit(string.format(
    "Commit %d/%d  \226\128\162  File %d/%d",
    S.commit_idx, #S.commits, #commit.files > 0 and S.file_idx or 0, #commit.files
  ), "Comment")
  emit("")
  emit(commit.short .. "  " .. commit.subject, "Title")
  emit(commit.author .. "  \226\128\162  " .. commit.date, "Comment")
  emit("")
  for _, body_line in ipairs(vim.split(commit.body, "\n", { plain = true })) do
    emit(vim.trim(body_line) ~= "" and ("  " .. body_line) or "")
  end
  emit("")
  emit(string.format("Files (%d)", #commit.files), "Title")
  if #commit.files == 0 then
    emit("  (no direct diff \226\128\148 merge commit)", "Comment")
  else
    for i, f in ipairs(commit.files) do
      local marker = i == S.file_idx and "\226\150\184 " or "  "
      local label = f.old_path and (f.old_path .. " \226\134\146 " .. f.path) or f.path
      emit(marker .. f.status .. " " .. label)
      if i == S.file_idx then current_lnum = #lines end
    end
  end
  emit("")
  emit("C-n/C-p file/commit \226\128\162 C-d/C-u page \226\128\162 q quit", "Comment")

  vim.bo[S.list_buf].modifiable = true
  vim.api.nvim_buf_set_lines(S.list_buf, 0, -1, false, lines)
  vim.bo[S.list_buf].modifiable = false
  vim.bo[S.list_buf].modified = false

  vim.api.nvim_buf_clear_namespace(S.list_buf, S.ns, 0, -1)
  for lnum, group in pairs(hl) do
    vim.api.nvim_buf_set_extmark(S.list_buf, S.ns, lnum - 1, 0, { end_col = #lines[lnum], hl_group = group })
  end
  if current_lnum then
    vim.api.nvim_buf_set_extmark(S.list_buf, S.ns, current_lnum - 1, 0, { end_col = #lines[current_lnum], hl_group = "PmenuSel" })
    pcall(vim.api.nvim_win_set_cursor, S.list_win, { current_lnum, 0 })
  end
end

local function placeholder_buf(text)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  vim.bo[buf].modified = false
  return buf
end

local function bind(buf)
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "<C-n>", M.next, vim.tbl_extend("force", opts, { desc = "History: next file, then next commit" }))
  vim.keymap.set("n", "<C-p>", M.prev, vim.tbl_extend("force", opts, { desc = "History: previous file, then previous commit" }))
  vim.keymap.set("n", "<C-d>", M.page_down, vim.tbl_extend("force", opts, { desc = "History: page down, then next file/commit" }))
  vim.keymap.set("n", "<C-u>", M.page_up, vim.tbl_extend("force", opts, { desc = "History: page up, then previous file/commit" }))
  vim.keymap.set("n", "q", M.quit, vim.tbl_extend("force", opts, { desc = "History: quit" }))
  vim.keymap.set("n", "<Esc>", M.quit, vim.tbl_extend("force", opts, { desc = "History: quit" }))
end

-- Loads commits[commit_idx].files[file_idx] into the fixed left/right diff
-- panes: left is the file's blob at this commit, right is its blob at the
-- parent. Added files have no parent blob, deleted files have no
-- this-commit blob, merge commits (no --name-status output) have no file at
-- all — each gets a placeholder pane instead of erroring.
local function show_current()
  local commit = S.commits[S.commit_idx]
  if not commit then return end
  local file = commit.files[S.file_idx]

  local left_buf, right_buf
  if not file then
    left_buf = placeholder_buf("(no direct diff \226\128\148 merge commit)")
    right_buf = placeholder_buf("")
  else
    local ft = vim.filetype.match({ filename = file.path }) or ""
    if file.status == "D" then
      left_buf = placeholder_buf("(deleted in this commit)")
    else
      left_buf = safe_load_rev(S.root, commit.hash, file.path, ft) or placeholder_buf("(submodule or binary \226\128\148 no text diff)")
    end

    if file.status == "A" or commit.parent == "" then
      right_buf = placeholder_buf("(new file \226\128\148 no parent version)")
    else
      local old_path = file.old_path or file.path
      right_buf = safe_load_rev(S.root, commit.parent, old_path, ft) or placeholder_buf("(submodule or binary \226\128\148 no text diff)")
    end
  end

  vim.api.nvim_win_set_buf(S.left_win, left_buf)
  vim.api.nvim_win_call(S.left_win, function() vim.cmd("diffthis") end)
  vim.api.nvim_win_set_buf(S.right_win, right_buf)
  vim.api.nvim_win_call(S.right_win, function() vim.cmd("diffthis") end)
  diffsplit.style_diff_windows(S.left_win, S.right_win)
  bind(left_buf)
  bind(right_buf)

  render_list()
  vim.api.nvim_set_current_win(S.left_win)
end

-- Steps file-by-file within the current commit, then commit-by-commit once
-- files run out (wrapping at both ends). `land_end`, used by page_down/up,
-- puts the cursor on the new file's last line instead of its first, so a
-- run of C-u across a file/commit boundary keeps scrolling upward through
-- history rather than snapping to the top of the next thing it lands on.
local function step(forward, land_end)
  if not S.active or #S.commits == 0 then return end
  local commit = S.commits[S.commit_idx]

  if forward then
    if S.file_idx < #commit.files then
      S.file_idx = S.file_idx + 1
    else
      S.commit_idx = S.commit_idx % #S.commits + 1
      S.file_idx = 1
    end
  else
    if S.file_idx > 1 then
      S.file_idx = S.file_idx - 1
    else
      S.commit_idx = (S.commit_idx - 2) % #S.commits + 1
      local files = S.commits[S.commit_idx].files
      S.file_idx = #files > 0 and #files or 1
    end
  end

  show_current()
  if land_end then
    vim.api.nvim_win_call(S.left_win, function() vim.cmd("normal! G") end)
  end
end

function M.next() step(true) end
function M.prev() step(false) end

-- <C-d>/<C-u>: native half-page scroll within the current file's diff;
-- once the cursor stops moving (already at the buffer's bottom/top), the
-- same keystroke rolls over into the next/previous file or commit, so
-- paging through a whole file's diff and then the next one feels like one
-- continuous scroll instead of two different gestures.
local function page(forward)
  if not S.active then return end
  local before = vim.api.nvim_win_get_cursor(S.left_win)
  vim.api.nvim_win_call(S.left_win, function()
    vim.cmd("normal! " .. (forward and "\4" or "\21"))
  end)
  local after = vim.api.nvim_win_get_cursor(S.left_win)
  if after[1] == before[1] and after[2] == before[2] then
    step(forward, not forward)
  end
end

function M.page_down() page(true) end
function M.page_up() page(false) end

function M.quit()
  if not S.active then return end
  S.active = false
  for _, win in ipairs({ S.list_win, S.left_win, S.right_win }) do
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  if S.origin_win and vim.api.nvim_win_is_valid(S.origin_win) then
    vim.api.nvim_set_current_win(S.origin_win)
  end
  S.root, S.commits, S.commit_idx, S.file_idx = nil, {}, 0, 0
  S.origin_win, S.list_win, S.list_buf, S.left_win, S.right_win = nil, nil, nil, nil, nil
end

function M.start()
  if S.active then
    vim.notify("History browser already active \226\128\148 C-n/C-p/C-d/C-u to navigate, q to quit", vim.log.levels.INFO)
    return
  end

  local root = diffsplit.git_root()
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end

  local commits = load_commits(root)
  if #commits == 0 then
    vim.notify("No commits", vim.log.levels.INFO)
    return
  end

  S.root, S.commits, S.commit_idx, S.file_idx = root, commits, 1, 1
  S.origin_win = vim.api.nvim_get_current_win()

  local width = math.floor(vim.o.columns * 0.94)
  local height = math.floor(vim.o.lines * 0.88)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local list_width = math.max(34, math.floor(width * 0.24))
  local gap = 2
  local diff_width = math.floor((width - list_width - 2 * gap) / 2)

  S.list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[S.list_buf].buftype = "nofile"
  vim.bo[S.list_buf].bufhidden = "wipe"
  S.list_win = vim.api.nvim_open_win(S.list_buf, true, {
    relative = "editor", width = list_width, height = height, row = row, col = col,
    style = "minimal", border = "rounded", title = " git log -p ", title_pos = "center",
  })
  bind(S.list_buf)

  local left_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[left_buf].bufhidden = "wipe"
  S.left_win = vim.api.nvim_open_win(left_buf, false, {
    relative = "editor", width = diff_width, height = height, row = row, col = col + list_width + gap,
    style = "minimal", border = "rounded", title = " commit ", title_pos = "center",
  })
  vim.wo[S.left_win].wrap = false

  local right_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[right_buf].bufhidden = "wipe"
  S.right_win = vim.api.nvim_open_win(right_buf, false, {
    relative = "editor", width = diff_width, height = height, row = row, col = col + list_width + gap + diff_width + gap,
    style = "minimal", border = "rounded", title = " parent ", title_pos = "center",
  })
  vim.wo[S.right_win].wrap = false

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
