-- Single source of truth for the treesitter parsers this config installs.
-- Required by lua/plugins/treesiter.lua (runtime install) and by the headless
-- installers in scripts/install.sh and the Dockerfile, so the two never drift.
--
-- Neovim >= 0.12 ships its own precompiled parsers for lua, vim, vimdoc,
-- markdown and markdown_inline (see /opt/neovim/lib/nvim/parser on Linux) —
-- they highlight natively with no plugin and no tree-sitter CLI involved, so
-- they're deliberately left out of this list. Installing them anyway would
-- just shadow a working native parser with a redundant CLI-built one, and on
-- a fresh box adds installs that depend on the tree-sitter CLI for no benefit.
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
}
