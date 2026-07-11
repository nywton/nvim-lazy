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

-- Whether `file` exists in HEAD at all — false for untracked files *and*
-- anything added-but-not-yet-committed. Those need a whole-file `git add`
-- instead of a hunk-level `git apply --cached`: the hunk's patch header
-- frames it as "new file, --- /dev/null", and applying that against
-- --cached conflicts the moment the file already has *some* content in the
-- index (from an earlier `git add`) — the "old side" claims empty, the
-- index blob isn't. Same guard git.review's accept_hunk uses.
local function has_head_version(root, file)
  vim.fn.system({ "git", "-C", root, "cat-file", "-e", "HEAD:" .. file })
  return vim.v.shell_error == 0
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

-- Diff command for the status preview pane — plain text, no --color/
-- --word-diff: the preview renders through git/delta.lua (same collapsed
-- header + full-line +/- coloring as <leader>gd/gL), which paints its own
-- extmarks over raw diff text and would just fight ANSI escape codes.
-- Untracked files have nothing to diff against in the index/HEAD, so
-- compare against /dev/null; everything else diffs straight against HEAD
-- (covers staged + unstaged in one call — same approach as git/signs.lua).
local function preview_diff_cmd(root, code, file)
  if code:sub(1, 1) == "?" then
    return { "git", "-C", root, "diff", "--no-index", "--", "/dev/null", file }
  end
  return { "git", "-C", root, "diff", "HEAD", "--", file }
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

  local function close()
    for _, w in ipairs({ list_win, preview_win }) do
      if vim.api.nvim_win_is_valid(w) then
        vim.api.nvim_win_close(w, true)
      end
    end
  end

  -- Forward-declared: refresh, hunk_action, bind_preview and update_preview
  -- all call into each other (bind_preview binds keys that call
  -- hunk_action, which calls refresh, which calls update_preview, which
  -- calls bind_preview again on the fresh buffer) — plain `local function`
  -- in sequence can't express that cycle, so the names are declared upfront
  -- and assigned below.
  local refresh, hunk_action, bind_preview, update_preview

  -- Re-fetches the file list (a staged/discarded hunk can move a file
  -- between sections, or drop it off the list entirely) while keeping the
  -- same file selected by path rather than by line number, since its line
  -- moves around as sections gain/lose entries.
  refresh = function(preserve_file)
    load_entries()
    if preserve_file then
      for lnum, e in pairs(entries) do
        if e.file == preserve_file then
          pcall(vim.api.nvim_win_set_cursor, list_win, { lnum, 0 })
          break
        end
      end
    end
    update_preview()
  end

  local function block_under_cursor(blocks)
    if not vim.api.nvim_win_is_valid(preview_win) then return nil end
    local lnum = vim.api.nvim_win_get_cursor(preview_win)[1]
    return require("git.delta").block_at(blocks, lnum)
  end

  -- Applies the raw patch for one resolved hunk. `args` is git-apply's own
  -- flags: {"--cached"} to stage it, {"-R"} to discard it from the working
  -- tree (index untouched — matches plain git semantics: discarding a
  -- staged hunk still leaves it staged until you also unstage).
  hunk_action = function(block, args, verb)
    local patch = table.concat(block.header, "\n") .. "\n" .. table.concat(block.lines, "\n") .. "\n"
    local cmd = { "git", "-C", root, "apply", "--whitespace=nowarn" }
    vim.list_extend(cmd, args)
    table.insert(cmd, "-")
    local result = vim.fn.system(cmd, patch)

    if vim.v.shell_error ~= 0 then
      vim.notify(verb .. " hunk failed: " .. vim.trim(result), vim.log.levels.ERROR)
    else
      vim.notify(verb .. "d hunk in " .. block.file, vim.log.levels.INFO)
      refresh(block.file)
    end
  end

  bind_preview = function(buf, blocks)
    local opts = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set("n", "s", function()
      local block = block_under_cursor(blocks)
      if not block then
        vim.notify("No hunk here", vim.log.levels.INFO)
        return
      end
      if not has_head_version(root, block.file) then
        vim.fn.system({ "git", "-C", root, "add", "--", block.file })
        vim.notify("Staged (new file): " .. block.file, vim.log.levels.INFO)
        refresh(block.file)
        return
      end
      hunk_action(block, { "--cached" }, "Stage")
    end, vim.tbl_extend("force", opts, { desc = "Stage hunk under cursor" }))
    vim.keymap.set("n", "d", function()
      local block = block_under_cursor(blocks)
      if not block then
        vim.notify("No hunk here", vim.log.levels.INFO)
        return
      end
      if vim.fn.confirm("Discard this hunk? This cannot be undone.", "&Yes\n&No", 2) == 1 then
        hunk_action(block, { "-R" }, "Discard")
      end
    end, vim.tbl_extend("force", opts, { desc = "Discard hunk under cursor" }))
    vim.keymap.set("n", "q", close, vim.tbl_extend("force", opts, { desc = "Close git status" }))
    vim.keymap.set("n", "<Esc>", close, vim.tbl_extend("force", opts, { desc = "Close git status" }))
  end

  update_preview = function()
    if not vim.api.nvim_win_is_valid(list_win) or not vim.api.nvim_win_is_valid(preview_win) then
      return
    end
    local lnum = vim.api.nvim_win_get_cursor(list_win)[1]
    local entry = entries[lnum]

    -- A fresh buffer per refresh, same as before — bufhidden=wipe cleans up
    -- the old one the moment it stops being displayed (right after
    -- nvim_win_set_buf below).
    local new_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[new_buf].buftype = "nofile"
    vim.bo[new_buf].bufhidden = "wipe"
    vim.api.nvim_win_set_buf(preview_win, new_buf)

    if entry then
      local out = vim.fn.systemlist(preview_diff_cmd(root, entry.code, entry.file))
      local lines, hl, blocks = require("git.delta").render(out)
      vim.bo[new_buf].modifiable = true
      vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, lines)
      vim.bo[new_buf].modifiable = false
      vim.bo[new_buf].modified = false
      local ns = vim.api.nvim_create_namespace("git_delta")
      for hl_lnum, group in pairs(hl) do
        vim.api.nvim_buf_set_extmark(new_buf, ns, hl_lnum - 1, 0, { end_col = #lines[hl_lnum], hl_group = group })
      end
      bind_preview(new_buf, blocks)
    else
      vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, { "(clean)" })
    end
  end

  load_entries()
  update_preview()

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
