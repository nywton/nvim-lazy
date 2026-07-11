-- Delta-inspired rendering for the plain `git diff`/`git log -p` scratch
-- buffers (git.commands' M.diff/M.log/M.log_repo). Not a port of delta
-- itself (see ./delta/ for the real thing) — just the handful of ideas
-- from it that pay off in a scratch buffer with no ANSI/terminal involved:
-- collapse each file's "diff --git"/"index"/"---"/"+++" boilerplate into
-- one label line, reduce "@@ ... @@" hunk headers to their line number and
-- function-context fragment, and paint +/- lines with a full-line
-- background instead of the generic 'diff' filetype's foreground-only
-- coloring.
local M = {}

-- git prepends a/ b/ c/ i/ o/ w/ mnemonic prefixes to paths in the
-- "diff --git" line (configurable via diff.mnemonicPrefix) — strip
-- whichever one shows up so the label reads as a plain relative path.
local function strip_prefix(path)
  return (path:gsub("^[abciow]/", ""))
end

local function file_label(old_path, new_path, flags)
  if flags.rename then
    return old_path .. " \226\134\146 " .. new_path -- old -> new
  elseif flags.binary then
    return new_path .. " (binary)"
  elseif flags.new_file or old_path == "/dev/null" then
    return new_path .. " (new)"
  elseif flags.deleted or new_path == "/dev/null" then
    return old_path .. " (deleted)"
  else
    return new_path
  end
end

-- Returns (rendered_lines, {[lnum] = hl_group}) — a plain array plus a
-- sparse map, mirroring the header_lines pattern already used by
-- git.commands/git.review for extmark application.
function M.render(raw_lines)
  local out, hl = {}, {}
  local i, n = 1, #raw_lines

  local function emit(text, group)
    table.insert(out, text)
    if group then hl[#out] = group end
  end

  while i <= n do
    local line = raw_lines[i]
    local old_path, new_path = line:match("^diff %-%-git a/(.-) b/(.*)$")

    if old_path then
      local flags = {}
      local minus_file, plus_file
      i = i + 1
      while i <= n do
        local l = raw_lines[i]
        if l:match("^@@") or l:match("^diff %-%-git ") or l:match("^commit ") then
          break
        elseif l:match("^new file mode") then
          flags.new_file = true
        elseif l:match("^deleted file mode") then
          flags.deleted = true
        elseif l:match("^rename from ") then
          flags.rename = true
          minus_file = l:match("^rename from (.*)$")
        elseif l:match("^rename to ") then
          flags.rename = true
          plus_file = l:match("^rename to (.*)$")
        elseif l:match("^Binary files ") then
          flags.binary = true
        elseif l:match("^%-%-%- ") then
          minus_file = l:match("^%-%-%- (.*)$")
        elseif l:match("^%+%+%+ ") then
          plus_file = l:match("^%+%+%+ (.*)$")
        end
        i = i + 1
      end
      minus_file = strip_prefix(minus_file or old_path)
      plus_file = strip_prefix(plus_file or new_path)
      emit("  " .. file_label(minus_file, plus_file, flags), "Title")
      emit("")
    else
      local new_start, context = line:match("^@@ %-%d+,?%d* %+(%d+),?%d* @@(.*)$")
      if new_start then
        context = vim.trim(context)
        if context ~= "" then
          emit("  " .. new_start .. "  " .. context, "Comment")
        end
        emit("")
      elseif line:match("^commit ") then
        emit(line, "Title")
      elseif line:match("^Author: ") or line:match("^Date:   ") or line:match("^Merge: ") then
        emit(line, "Comment")
      elseif line:sub(1, 1) == "+" then
        emit(line, "DiffAdd")
      elseif line:sub(1, 1) == "-" then
        emit(line, "DiffDelete")
      else
        emit(line)
      end
      i = i + 1
    end
  end

  return out, hl
end

-- Renders straight into a scratch buffer: sets lines, then paints the
-- extmarks from the sparse hl map returned by M.render.
function M.render_to_buffer(buf, raw_lines)
  local lines, hl = M.render(raw_lines)

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false

  local ns = vim.api.nvim_create_namespace("git_delta")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for lnum, group in pairs(hl) do
    vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, { end_col = #lines[lnum], hl_group = group })
  end
end

return M
