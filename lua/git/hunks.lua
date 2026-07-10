-- Repo-wide uncommitted-hunk navigation. Lifted out of the old
-- gitsigns.setup() callback in plugins/git.lua — this logic never actually
-- depended on gitsigns, it just lived inside its config function. Parses
-- `git diff -U0` output directly.
local M = {}

local function get_all_hunks()
  local git_root = vim.trim(vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"))
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local hunks = {}
  local seen = {}

  local function parse_diff(lines)
    local current_file = nil
    for _, line in ipairs(lines) do
      local file = line:match("^%+%+%+ b/(.+)$")
      if file then
        current_file = git_root .. "/" .. file
      end
      local lnum = line:match("^@@ %-[%d,]+ %+(%d+)")
      if lnum and current_file then
        local key = current_file .. ":" .. lnum
        if not seen[key] then
          seen[key] = true
          table.insert(hunks, { file = current_file, lnum = tonumber(lnum) })
        end
      end
    end
  end

  parse_diff(vim.fn.systemlist("git -C " .. vim.fn.shellescape(git_root) .. " diff -U0 2>/dev/null"))
  parse_diff(vim.fn.systemlist("git -C " .. vim.fn.shellescape(git_root) .. " diff -U0 --cached 2>/dev/null"))

  table.sort(hunks, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    return a.lnum < b.lnum
  end)

  return hunks
end

local function nav(direction)
  local hunks = get_all_hunks()
  if #hunks == 0 then
    vim.notify("No uncommitted changes", vim.log.levels.INFO)
    return
  end

  local cur_file = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]

  local target_idx
  if direction == "next" then
    for i, h in ipairs(hunks) do
      if h.file > cur_file or (h.file == cur_file and h.lnum > cur_line) then
        target_idx = i
        break
      end
    end
    target_idx = target_idx or 1
  else
    for i = #hunks, 1, -1 do
      local h = hunks[i]
      if h.file < cur_file or (h.file == cur_file and h.lnum < cur_line) then
        target_idx = i
        break
      end
    end
    target_idx = target_idx or #hunks
  end

  local h = hunks[target_idx]
  if h.file ~= cur_file then
    vim.cmd("edit " .. vim.fn.fnameescape(h.file))
  end
  vim.api.nvim_win_set_cursor(0, { h.lnum, 0 })
  vim.cmd("normal! zz")
end

function M.next()
  if vim.wo.diff then
    vim.cmd("normal! ]c")
    return
  end
  nav("next")
end

function M.prev()
  if vim.wo.diff then
    vim.cmd("normal! [c")
    return
  end
  nav("prev")
end

return M
