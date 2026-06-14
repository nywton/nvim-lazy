-- ===========================================================================
-- Dependency-free format-on-save for filetypes with no Node-free formatter.
--
-- Real JS/TS/JSON/CSS pretty-printing (prettier/biome) needs a JavaScript
-- runtime this config deliberately doesn't ship. Treesitter parses but does
-- not pretty-print, so this does the most that's possible with zero external
-- dependencies, on save:
--   1. trim trailing whitespace
--   2. drop trailing blank lines (keep a single final newline)
--   3. re-indent the whole buffer with the Treesitter indentexpr (the `=`
--      operator) — set per-buffer in lua/plugins/treesiter.lua
--
-- This normalizes indentation/whitespace; it will NOT rewrite quotes, add
-- semicolons, or wrap long lines. For that you need an external formatter.
-- ===========================================================================
local M = {}

-- Filetypes handled here (those with no Node-free external formatter or LSP).
-- Exposed so conform.nvim can defer to us instead of double-formatting.
M.filetypes = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  json = true,
  jsonc = true,
  css = true,
  scss = true,
  html = true,
  eruby = true, -- .erb (Treesitter parser: embedded_template)
  slim = true,
}

local function format(buf)
  -- Preserve cursor/scroll across the rewrite.
  local view = vim.fn.winsaveview()

  -- Trim trailing whitespace without clobbering the search register/history.
  vim.cmd([[silent! keeppatterns %s/\s\+$//e]])

  -- Collapse trailing blank lines to a single final newline.
  local last = vim.api.nvim_buf_line_count(buf)
  while last > 1 do
    local line = vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1]
    if line == "" then
      vim.api.nvim_buf_set_lines(buf, last - 1, last, false, {})
      last = last - 1
    else
      break
    end
  end

  -- Re-indent via Treesitter (`=`), but only if a parser is actually loaded —
  -- otherwise `=` would fall back to (worse) heuristics or error.
  if pcall(vim.treesitter.get_parser, buf) then
    vim.cmd("silent! normal! gg=G")
  end

  vim.fn.winrestview(view)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("TsFormatOnSave", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    callback = function(args)
      if M.filetypes[vim.bo[args.buf].filetype] then
        format(args.buf)
      end
    end,
  })
end

return M
