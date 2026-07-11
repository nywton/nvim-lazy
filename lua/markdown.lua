-- Markdown preview, entirely built-in: $VIMRUNTIME/syntax/markdown.vim
-- already renders headers, **bold**/*italic*/`code` (via 'conceal', hiding
-- the markup characters) and language-highlighted fenced code blocks — it's
-- just off by default (conceallevel=0). No renderer, no external binary:
-- this only flips conceallevel on for markdown buffers and gives it a
-- buffer-local toggle back to the raw source.
vim.g.markdown_fenced_languages = {
  "lua", "vim", "bash=sh", "sh", "zsh", "python", "ruby", "javascript",
  "typescript", "json", "yaml", "toml", "html", "css", "go", "rust", "c", "cpp",
}

local function toggle_preview()
  vim.wo.conceallevel = vim.wo.conceallevel == 0 and 2 or 0
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    vim.wo.conceallevel = 2
    vim.wo.concealcursor = "nc"
    vim.keymap.set("n", "<leader>mp", toggle_preview,
      { buffer = args.buf, desc = "Toggle markdown preview / raw source" })
  end,
})
