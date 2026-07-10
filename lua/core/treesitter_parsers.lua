-- Single source of truth for the treesitter parsers this config installs.
--
-- Neovim >= 0.12 ships its own precompiled parsers for lua, vim, vimdoc,
-- markdown and markdown_inline — they highlight natively with no plugin and
-- no tree-sitter CLI involved, so they're deliberately left out of this list.
return {
  "json",
  "javascript",
  "typescript",
  "tsx",
  "yaml",
  "html",
  "css",
  "scss",
  "embedded_template", -- ERB / .erb templates (filetype: eruby)
  "slim",
  "bash",
  "dockerfile",
  "gitignore",
  "ruby",
  "python",
  "diff", -- git status preview pane (lua/git/commands.lua)
}
