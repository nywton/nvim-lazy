-- Current-line blame as dimmed virtual text at end of line, refreshed on
-- CursorHold. Uses `git blame --porcelain -L n,n` for just the current line
-- (cheap) run asynchronously via vim.system so it never blocks the editor.
-- Toggled per-buffer with <leader>gb. For the full-file blame history, see
-- git/commands.lua's M.blame() (<leader>gB).
local M = {}

local ns = vim.api.nvim_create_namespace("git_blame_inline")
local enabled = {} -- [bufnr] = true
local group = vim.api.nvim_create_augroup("GitBlameInline", { clear = true })

local function git_root(dir)
  local root = vim.trim(vim.fn.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }))
  return vim.v.shell_error == 0 and root or nil
end

local function relative_date(unix_ts)
  local diff = os.time() - tonumber(unix_ts)
  local mins = math.floor(diff / 60)
  if mins < 1 then return "just now" end
  if mins < 60 then return mins .. "m ago" end
  local hours = math.floor(mins / 60)
  if hours < 24 then return hours .. "h ago" end
  local days = math.floor(hours / 24)
  if days < 30 then return days .. "d ago" end
  local months = math.floor(days / 30)
  if months < 12 then return months .. "mo ago" end
  return math.floor(months / 12) .. "y ago"
end

-- Parses `git blame --porcelain -L n,n` output. First line is
-- "<hash> <orig-line> <final-line> [<num-lines>]"; header fields follow
-- until the first line that starts with a tab (the source line itself).
local function parse_porcelain(lines)
  local info = { hash = lines[1] and lines[1]:match("^(%x+)") }
  for _, line in ipairs(lines) do
    if line:sub(1, 1) == "\t" then
      break
    end
    local author = line:match("^author (.+)$")
    if author then info.author = author end
    local time = line:match("^author%-time (%d+)$")
    if time then info.time = time end
  end
  return info
end

local function render(buf, lnum, info)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not info or not info.hash then return end

  local text
  if info.hash:match("^0+$") then
    text = "Not committed yet"
  else
    text = string.format(
      "%s, %s \226\128\162 %s",
      info.author or "unknown",
      info.time and relative_date(info.time) or "",
      info.hash:sub(1, 8)
    )
  end

  vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, -1, {
    virt_text = { { "  " .. text, "Comment" } },
    virt_text_pos = "eol",
  })
end

local function update(buf)
  if not enabled[buf] then return end
  local filename = vim.api.nvim_buf_get_name(buf)
  if filename == "" or vim.bo[buf].buftype ~= "" then return end

  local root = git_root(vim.fn.fnamemodify(filename, ":h"))
  if not root then return end

  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end
  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  local relpath = filename:sub(#root + 2)

  vim.system(
    { "git", "-C", root, "blame", "--porcelain", "-L", lnum .. "," .. lnum, "--", relpath },
    { text = true },
    vim.schedule_wrap(function(res)
      if not enabled[buf] or res.code ~= 0 then return end
      -- Bail if the cursor moved on since the job started.
      local cur_win = vim.fn.bufwinid(buf)
      if cur_win == -1 or vim.api.nvim_win_get_cursor(cur_win)[1] ~= lnum then return end
      render(buf, lnum, parse_porcelain(vim.split(res.stdout or "", "\n")))
    end)
  )
end

function M.enable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if enabled[buf] then return end
  enabled[buf] = true
  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "BufEnter" }, {
    group = group,
    buffer = buf,
    callback = function() update(buf) end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = function() enabled[buf] = nil end,
  })
  update(buf)
end

function M.disable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  enabled[buf] = nil
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  pcall(vim.api.nvim_clear_autocmds, { group = group, buffer = buf })
end

function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if enabled[buf] then
    M.disable(buf)
  else
    M.enable(buf)
  end
end

return M
