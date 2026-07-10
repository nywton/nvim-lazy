-- Plugin-free toggleable floating terminal. Keeps one reusable terminal
-- buffer so toggling never spawns a brand new shell unless the old one was
-- closed. Also where you run git push/pull/commit/rebase — see
-- git/commands.lua for why those aren't wrapped in keymaps.

local state = { buf = -1, win = -1 }

local function open_win()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  return vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " terminal ",
    title_pos = "center",
  })
end

local function hide()
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_hide(state.win)
    state.win = -1
  end
end

local function show()
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    vim.cmd("startinsert")
    return
  end

  if not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
  end

  state.win = open_win()

  if vim.bo[state.buf].buftype ~= "terminal" then
    vim.fn.jobstart(vim.o.shell, { term = true })
  end

  vim.cmd("startinsert")
end

vim.keymap.set("n", "<leader>t", show, { desc = "Open/focus terminal" })

-- Two-stage Esc, scoped to the terminal buffer only (so it never shadows
-- <leader>/<Esc> in normal buffers): first Esc drops out of insert/job mode
-- into Terminal-Normal so you can use motions and visual mode on the
-- scrollback; second Esc (already in normal mode) hides the float.
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(args)
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = args.buf, desc = "Terminal: normal mode" })
    vim.keymap.set("n", "<Esc>", hide, { buffer = args.buf, desc = "Terminal: hide" })
  end,
})

-- Neovim normally leaves a "[Process exited N]" terminal buffer sitting
-- there until you press a key. Close it immediately instead — on `exit`/
-- Ctrl-D the float disappears with no notice to dismiss, and the next
-- <leader>t starts a brand new shell.
vim.api.nvim_create_autocmd("TermClose", {
  callback = function(args)
    if args.buf ~= state.buf then
      return
    end
    vim.schedule(function()
      hide()
      if vim.api.nvim_buf_is_valid(state.buf) then
        vim.api.nvim_buf_delete(state.buf, { force = true })
      end
      state.buf = -1
    end)
  end,
})
