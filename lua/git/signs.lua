-- Bare sign-column indicators for uncommitted changes — the one feature lost
-- by dropping gitsigns.nvim. Parses `git diff -U0` per-buffer and places
-- +/~/_ via extmarks (core API, no plugin). Colors come from the
-- GitSignsAdd/Change/Delete highlight groups defined in core/colorscheme.lua.
--
-- Two states, not one: `git diff HEAD` (staged+unstaged combined) decides
-- *which* lines get a sign, same as before, but each sign is then checked
-- against `git diff` (index-vs-worktree, unstaged only) to see whether it's
-- still genuinely unstaged or already `git add`ed — see git/review.lua's
-- hunk-level accept, which is what actually produces that second state.
-- Both diffs report line numbers against the working tree (the "new" side
-- in both cases), so they line up without any remapping.
--
-- No current-line blame, no stage/reset-hunk from here — see git/hunks.lua
-- for ]c/[c navigation and git/commands.lua's status buffer (`s`/`u`) for
-- staging.
local M = {}

local ns = vim.api.nvim_create_namespace("git_signs")

local function git_root(dir)
  local root = vim.trim(vim.fn.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }))
  return vim.v.shell_error == 0 and root or nil
end

local function is_untracked(root, relpath)
  local out = vim.fn.systemlist({ "git", "-C", root, "status", "--porcelain", "--", relpath })
  return out[1] ~= nil and out[1]:sub(1, 2) == "??"
end

-- Parses `git diff -U0` hunk headers into { {old_start, old_count, new_start,
-- new_count}, ... }. Counts are omitted by git when they equal 1.
local function parse_hunks(diff_lines)
  local hunks = {}
  for _, line in ipairs(diff_lines) do
    local os_, oc, ns_, nc = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
    if os_ then
      table.insert(hunks, {
        old_start = tonumber(os_),
        old_count = oc == "" and 1 or tonumber(oc),
        new_start = tonumber(ns_),
        new_count = nc == "" and 1 or tonumber(nc),
      })
    end
  end
  return hunks
end

-- Converts hunks into { {lnum, text, hl}, ... } sign placements.
local function hunks_to_signs(hunks)
  local signs = {}
  for _, h in ipairs(hunks) do
    if h.new_count == 0 then
      -- Pure deletion: no lines survive at new_start. Mark the line it
      -- happened before (or line 1, specially, if it happened at the top).
      if h.new_start == 0 then
        table.insert(signs, { lnum = 1, text = "‾", hl = "GitSignsDelete" })
      else
        table.insert(signs, { lnum = h.new_start, text = "_", hl = "GitSignsDelete" })
      end
    else
      for i = 0, h.new_count - 1 do
        local is_change = h.old_count > 0 and i < h.old_count
        table.insert(signs, {
          lnum = h.new_start + i,
          text = is_change and "~" or "+",
          hl = is_change and "GitSignsChange" or "GitSignsAdd",
        })
      end
    end
  end
  return signs
end

local STAGED_HL = {
  GitSignsAdd = "GitSignsStagedAdd",
  GitSignsChange = "GitSignsStagedChange",
  GitSignsDelete = "GitSignsStagedDelete",
}

function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  if vim.bo[buf].buftype ~= "" then
    return
  end
  local filename = vim.api.nvim_buf_get_name(buf)
  if filename == "" then
    return
  end

  local root = git_root(vim.fn.fnamemodify(filename, ":h"))
  if not root then
    return
  end
  local relpath = filename:sub(#root + 2)

  local head_diff, unstaged_diff
  if is_untracked(root, relpath) then
    -- Nothing to stage-vs-unstage yet — untracked files are all one state.
    head_diff = vim.fn.systemlist({ "git", "-C", root, "diff", "--no-index", "-U0", "--", "/dev/null", relpath })
    unstaged_diff = head_diff
  else
    head_diff = vim.fn.systemlist({ "git", "-C", root, "diff", "HEAD", "-U0", "--", relpath })
    unstaged_diff = vim.fn.systemlist({ "git", "-C", root, "diff", "-U0", "--", relpath })
  end

  local still_unstaged = {}
  for _, s in ipairs(hunks_to_signs(parse_hunks(unstaged_diff))) do
    still_unstaged[s.lnum] = true
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  for _, s in ipairs(hunks_to_signs(parse_hunks(head_diff))) do
    if s.lnum >= 1 and s.lnum <= line_count then
      local hl = still_unstaged[s.lnum] and s.hl or (STAGED_HL[s.hl] or s.hl)
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, s.lnum - 1, 0, {
        sign_text = s.text,
        sign_hl_group = hl,
        priority = 6,
      })
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("GitSigns", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
    group = group,
    callback = function(args)
      M.refresh(args.buf)
    end,
  })
end

return M
