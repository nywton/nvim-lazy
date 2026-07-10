-- Real-buffer preview pane for the fzf pickers (finder.files/finder.grep) —
-- a genuine Neovim buffer with treesitter highlighting, filling in for what
-- fzf's own `--preview 'cat -n ...'` can't do: syntax highlighting, and
-- landing the cursor precisely on the matched line/word.
--
-- fzf still owns the list, filtering and input. Its own `--preview` command
-- (kept invisible via --preview-window 0 — see finder.grep's preview_cmd
-- comment for why a --preview and not a `focus` bind) shells out to `nvim
-- --server $NVIM --remote-expr` on every list update — Neovim auto-sets
-- $NVIM inside :terminal/jobstart(term=true) jobs for exactly this "connect
-- back to the editor" use case (:h terminal) — which calls back into *this*
-- running instance to refresh the preview buffer. Same trick telescope's
-- previewer does, just driven by fzf's own preview mechanism instead of a
-- Lua callback.
local M = {}

local ns = vim.api.nvim_create_namespace("finder_preview")

local state = {
  win = nil,
  buf = nil,
  file = nil,
  root = nil,
}

-- Take over the buffer already showing in `win` (created by finder.picker)
-- as the preview buffer, rather than creating a new one and swapping it in.
function M.attach(win, root)
  state.win = win
  state.root = root
  state.file = nil
  state.buf = vim.api.nvim_win_get_buf(win)
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].swapfile = false
end

function M.close()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end
  state.win, state.buf, state.file, state.root = nil, nil, nil, nil
end

local function abspath(path)
  if path:sub(1, 1) == "/" then return path end
  return (state.root or vim.fn.getcwd()) .. "/" .. path
end

local function load_file(path)
  if state.file == path then return end
  state.file = path

  local buf = state.buf
  vim.bo[buf].modifiable = true
  pcall(vim.treesitter.stop, buf)

  if vim.fn.filereadable(path) == 1 then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(path, "", 5000))
    local ft = vim.filetype.match({ filename = path })
    vim.bo[buf].filetype = ft or ""
    if ft then
      local lang = vim.treesitter.language.get_lang(ft) or ft
      pcall(vim.treesitter.start, buf, lang)
    end
  else
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "(no preview)" })
  end

  vim.bo[buf].modifiable = false
end

-- Plain file preview (find_files has no line/col to land on).
function M.show_file(rel_or_abs)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return "" end
  load_file(abspath(rel_or_abs))
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
  return ""
end

-- A grep match (live_grep/goto_word): lands on lnum/col and, if `word` is
-- given, highlights it the way telescope highlights the match in preview.
function M.show_match(rel_or_abs, lnum, col, word)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return "" end
  load_file(abspath(rel_or_abs))
  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

  local count = vim.api.nvim_buf_line_count(state.buf)
  lnum = math.min(math.max(tonumber(lnum) or 1, 1), count)
  local coln = math.max((tonumber(col) or 1) - 1, 0)

  pcall(vim.api.nvim_win_set_cursor, state.win, { lnum, coln })
  vim.api.nvim_win_call(state.win, function() vim.cmd("normal! zz") end)

  if word and word ~= "" then
    local text = vim.api.nvim_buf_get_lines(state.buf, lnum - 1, lnum, false)[1] or ""
    local s = text:find(word, 1, true)
    if s then
      vim.api.nvim_buf_add_highlight(state.buf, ns, "IncSearch", lnum - 1, s - 1, s - 1 + #word)
    end
  end
  return ""
end

-- base64 wrappers: entry points for the `nvim --remote-expr` calls fzf's
-- focus bind makes, so arbitrary filenames/words don't need shell-quoting
-- gymnastics across the picker -> fzf -> $SHELL -> remote-expr hops.
local function b64dec(s) return s ~= "" and vim.base64.decode(s) or "" end

function M.show_file_b64(path_b64) return M.show_file(b64dec(path_b64)) end

function M.show_match_b64(path_b64, lnum, col, word_b64)
  local word = word_b64 ~= "" and b64dec(word_b64) or nil
  return M.show_match(b64dec(path_b64), lnum, col, word)
end

return M
