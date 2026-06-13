# Neovim Config

A lean Lua config built on [lazy.nvim](https://github.com/folke/lazy.nvim), aimed at Ruby, JavaScript/TypeScript and Python.

Requires Neovim **0.11+** (uses the `vim.lsp.config`/`vim.lsp.enable` API).

## What's inside

- **LSP** via mason + nvim-lspconfig — `ruby_lsp`, `ts_ls`, `pyright`, `html`, `cssls`, `tailwindcss` (auto-installed on first launch)
- **Completion**: [blink.cmp](https://github.com/saghen/blink.cmp) (LSP, path, snippets, buffer + cmdline)
- **Formatting on save**: [conform.nvim](https://github.com/stevearc/conform.nvim) — `stylua` (lua), `rubocop` (ruby), `black` (python); other filetypes fall back to the LSP
- **Treesitter** highlighting + `nvim-ts-autotag`
- **Fuzzy find**: telescope · **Git**: fugitive + gitsigns · **Nav**: harpoon
- **UI**: catppuccin, lualine, indent-blankline, colorizer

## Install

```bash
git clone https://github.com/nywton/nvim-lazy ~/.config/nvim
nvim   # plugins, LSP servers and parsers install on first run
```

### External tools

Install LSP servers via `:Mason`. Formatters must be on `PATH`:

```bash
# macOS (brew) — adjust for your platform
brew install cmake stylua   # cmake: needed to build native Ruby gems (e.g. rugged)
gem install rubocop
pip install black
```

System tooling (Arch example):

```bash
sudo pacman -S base-devel git cmake unzip ninja curl fd ripgrep neovim
```

## Fonts

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

## Keymaps

Leader is `<Space>`. Press `<leader>t` (Telescope keymaps) to browse everything; LSP maps (`gd`, `gr`, `K`, `<leader>ca`, `<leader>rn`, …) are active in buffers with an attached language server.
