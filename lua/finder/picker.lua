-- Shared floating chrome for the rg+fzf pickers (find_files, goto_word,
-- live_grep) — a centered window like telescope/git.commands.status instead
-- of a bottom split. fzf still does all the filtering/preview itself (via
-- --preview); this module only owns the window and Esc-to-close, which a
-- bare terminal job doesn't give you for free.
local M = {}

function M.open(cmd, on_exit)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)
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
  })

  local closed = false
  local job_id

  local function close()
    if closed then return end
    closed = true
    if job_id then pcall(vim.fn.jobstop, job_id) end
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    on_exit()
  end

  job_id = vim.fn.jobstart(cmd, { term = true, on_exit = close })

  -- nowait: without it, the global <Esc><Esc> terminal-mode mapping
  -- (terminal.lua) makes Neovim wait timeoutlen to see if a second Esc is
  -- coming before forwarding the first one to fzf, which feels laggy.
  -- Buffer-local + nowait makes a single Esc close the picker instantly.
  vim.keymap.set("t", "<Esc>", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })

  vim.cmd("startinsert")
end

return M
