-- Single source of truth for the treesitter parsers this config installs.
-- Required by lua/plugins/treesiter.lua (runtime install) and by the headless
-- installers in scripts/install.sh and the Dockerfile, so the two never drift.
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
  "markdown",
  "markdown_inline",
  "bash",
  "lua",
  "vim",
  "vimdoc",
  "dockerfile",
  "gitignore",
  "ruby",
  "python",
}
