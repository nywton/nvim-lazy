-- Shared floating chrome for the rg+fzf pickers (find_files, goto_word,
-- live_grep) — a centered two-pane window: fzf's list on the left, a real
-- treesitter-highlighted Neovim buffer on the right (finder.preview),
-- mirroring telescope's layout instead of a bottom split. fzf still does
-- all the filtering/picking itself; this module owns the windows, wires
-- the preview pane to it, and gives Esc-to-close, which a bare terminal job
-- doesn't give you for free.
local preview = require("finder.preview")
local M = {}

-- cmd's `--preview` (built by the caller, paired with --preview-window 0 to
-- stay invisible) is what keeps the preview pane in sync — see
-- finder.preview's header comment and finder.grep's preview_cmd comment for
-- why it's a --preview and not a `focus` bind.
function M.open(cmd, root, on_exit)
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local list_width = math.floor(width * 0.4)
  local gap = 1
  local preview_width = width - list_width - gap

  local list_buf = vim.api.nvim_create_buf(false, true)
  local list_win = vim.api.nvim_open_win(list_buf, true, {
    relative = "editor",
    width = list_width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  local preview_buf = vim.api.nvim_create_buf(false, true)
  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = "editor",
    width = preview_width,
    height = height,
    row = row,
    col = col + list_width + gap,
    style = "minimal",
    border = "rounded",
  })
  vim.wo[preview_win].number = true
  vim.wo[preview_win].cursorline = true
  vim.wo[preview_win].wrap = false
  preview.attach(preview_win, root)

  local closed = false
  local job_id

  local function close()
    if closed then return end
    closed = true
    if job_id then pcall(vim.fn.jobstop, job_id) end
    preview.close()
    if vim.api.nvim_win_is_valid(preview_win) then vim.api.nvim_win_close(preview_win, true) end
    if vim.api.nvim_win_is_valid(list_win) then vim.api.nvim_win_close(list_win, true) end
    if vim.api.nvim_buf_is_valid(list_buf) then vim.api.nvim_buf_delete(list_buf, { force = true }) end
    on_exit()
  end

  job_id = vim.fn.jobstart(cmd, { term = true, on_exit = close })

  -- Safety net: if either window goes away by some path other than close()
  -- itself (:q, :bd, <C-w>c on the preview pane, ...) the job's on_exit
  -- would never fire and the other window/buffer would leak. WinClosed on
  -- both, guarded by the `closed` flag above, guarantees the terminal job
  -- is stopped and both scratch buffers are freed no matter which side
  -- goes down first.
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = string.format("%d,%d", list_win, preview_win),
    once = true,
    callback = close,
  })

  -- nowait: without it, the global <Esc><Esc> terminal-mode mapping
  -- (terminal.lua) makes Neovim wait timeoutlen to see if a second Esc is
  -- coming before forwarding the first one to fzf, which feels laggy.
  -- Buffer-local + nowait makes a single Esc close the picker instantly.
  vim.keymap.set("t", "<Esc>", close, { buffer = list_buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = list_buf, nowait = true })
  vim.keymap.set("n", "q", close, { buffer = list_buf, nowait = true })

  vim.cmd("startinsert")
end

return M
