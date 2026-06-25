# Neovim Config

[![CI](https://github.com/nywton/nvim-lazy/actions/workflows/ci.yml/badge.svg)](https://github.com/nywton/nvim-lazy/actions/workflows/ci.yml)

A lean, **Node-free** Lua config built on [lazy.nvim](https://github.com/folke/lazy.nvim), aimed at Ruby, JavaScript/TypeScript and Python. Runs on **Ubuntu/Debian, macOS**, and in a **Docker** container.

Requires Neovim **0.12.0+** (nvim-treesitter's `main` branch and the `vim.lsp.config`/`vim.lsp.enable` API need it).

> **No JavaScript runtime required.** This config never installs or runs Node/npm. JS/TS/HTML/CSS/JSON/ERB get Treesitter highlighting, indentation, and dependency-free format-on-save (Treesitter re-indent + whitespace normalization — see [`lua/config/tsformat.lua`](lua/config/tsformat.lua)). Ruby uses `ruby_lsp` (gem) and Python uses `jedi-language-server` (pip). Treesitter parsers are built by the [`tree-sitter` CLI](https://github.com/tree-sitter/tree-sitter) (a single Rust binary) invoking the system C compiler — required by nvim-treesitter's `main` branch.

---

## Requirements

The one-command installer and the Docker image (both under [Quick start](#quick-start)) set all of this up for you. This list matters only if you install **manually** or onto an unusual environment.

### Required

| Dependency | Why |
|---|---|
| **Neovim 0.12.0+** | nvim-treesitter `main` branch (hard-errors below 0.12) and the `vim.lsp.config` API. 0.11 and earlier are unsupported. |
| **git, curl, unzip, tar** | Bootstrapping lazy.nvim, cloning plugins, downloading release binaries. |
| **C compiler + build tools** — `build-essential` (gcc/`cc`), `cmake`, `ninja`, `gettext`, `pkg-config` | Treesitter parsers are compiled locally from C. |
| **[`tree-sitter` CLI](https://github.com/tree-sitter/tree-sitter)** (single Rust binary) | nvim-treesitter `main` shells out to `tree-sitter build` to compile every parser. **Without it, no parser installs.** Get it from the [releases](https://github.com/tree-sitter/tree-sitter/releases), `brew install tree-sitter`, or `cargo install tree-sitter-cli`. |
| **A UTF-8 locale** (e.g. `en_US.UTF-8`) | Neovim's `:checkhealth` errors without one; unicode UI glyphs need it. |

### Recommended

| Dependency | Why |
|---|---|
| **ripgrep** (`rg`) | Telescope live-grep and `:grep`. |
| **fd** (`fd` / `fdfind`) | Faster Telescope file finding. |
| **System clipboard tool** | The `"+`/`"*` registers. `xclip` or `wl-clipboard` on Linux; built in on macOS (`pbcopy`); auto-wired on WSL (`clip.exe`). |
| **python3 + pip** | Runtime for `jedi-language-server` (Python LSP) and the `black` formatter. |
| **A [Nerd Font](#fonts)** | Icons in the statusline and pickers. Installed automatically (JetBrainsMono Nerd Font); set your terminal to use it. |

### Installed automatically by the installer — nothing to do

- **Ruby** — via [rbenv](https://github.com/rbenv/rbenv): Ruby **3.4.9** (pinned, `rbenv global`), for `ruby_lsp` and `rubocop`. Override with `RUBY_VERSION=…`, or skip with `NO_RUBY=1`. (Manual route: `rbenv install 3.4.9 && rbenv global 3.4.9`.)
- **Shell** — `zsh` + [oh-my-zsh](https://ohmyz.sh) + `zsh-autosuggestions` + `zsh-syntax-highlighting` + `fzf`, wired into `~/.zshrc` via a guarded block. Skip with `NO_SHELL=1`. (Setting zsh as your login shell is left to you: `chsh -s "$(command -v zsh)"`.)
- **Plugins** — lazy.nvim on first launch, pinned to `lazy-lock.json`.
- **LSP servers** — via [Mason](https://github.com/williamboman/mason.nvim): `ruby_lsp`, `jedi_language_server`. (No JS/TS LSP — biome was dropped because Mason installs it via npm; JS/TS get Treesitter only.)
- **Formatters** — `stylua`, best-effort `black` (pip) and `rubocop` (gem).

### Explicitly *not* required

- **Node.js / npm** — this config is Node-free by design. JS/TS/HTML/CSS/JSON/ERB are formatted dependency-free via Treesitter (no biome/prettier/ts_ls); the Python LSP (jedi) is pure Python.

---

## Quick start

### Local (Ubuntu / Debian / macOS) — one command

Installs Neovim (latest stable, 0.12+), the required tools, clones this repo to `~/.config/nvim`, and syncs all plugins. **Re-run it any time to update everything.**

```bash
curl -fsSL https://raw.githubusercontent.com/nywton/nvim-lazy/main/scripts/install.sh | bash
```

Then just run `nvim` (LSP servers install on first use via `:Mason`).

Already cloned? Update in place:

```bash
~/.config/nvim/scripts/install.sh        # or: cd ~/.config/nvim && git pull && nvim "+Lazy! sync" +qa
```

<details>
<summary>What the script installs</summary>

- **Neovim** — latest stable from the official GitHub release (tarball on Linux, brew on macOS)
- **System tools** — `git curl unzip`, C toolchain (`build-essential`/Xcode CLT, `cmake`, `ninja`), the [`tree-sitter` CLI](https://github.com/tree-sitter/tree-sitter) that compiles Treesitter parsers, `ripgrep`, `fd`, `python3`, and `xclip`/`wl-clipboard` (system clipboard)
- **Locale** — generates `en_US.UTF-8` if missing (Neovim's `:checkhealth` errors without a UTF-8 locale)
- **Ruby** — [rbenv](https://github.com/rbenv/rbenv) + ruby-build, then Ruby `3.4.9` (pinned, set as `rbenv global`) for `ruby_lsp` and `rubocop`
- **Shell** — `zsh` + [oh-my-zsh](https://ohmyz.sh), `zsh-autosuggestions`, `zsh-syntax-highlighting`, and `fzf`; wired into `~/.zshrc` via a single guarded block (your existing `~/.zshrc` is never overwritten)
- **tmux** — `tmux`, a dependency-free `~/.config/tmux/stats.sh` (CPU/GPU/RAM/DISK, refreshed every 5s), and a Catppuccin Mocha `~/.tmux.conf` (pure tmux, no TPM/plugins). The base config is written only if you don't already have one; the stats status bar is added/refreshed on **every** run via a guarded managed block, so re-running picks it up even on top of an existing config. Skip with `NO_TMUX=1`
- **Font** — JetBrainsMono Nerd Font into `~/.local/share/fonts` (Linux) or via brew cask (macOS); skip with `NO_FONT=1`
- **Formatters** — `stylua` (lua), best-effort `black` (python, pip) and `rubocop` (ruby, gem)
- **LSP binaries** `jedi-language-server` (and `ruby-lsp`, given a Ruby) install automatically via Mason on first launch

Every step is **idempotent** — re-run any time to update; already-installed pieces are just checked/updated.

Override defaults with env vars: `REPO_URL`, `NVIM_DIR`, `RUBY_VERSION` (default `3.4.9`), `NO_SYNC=1`, `NO_RUBY=1`, `NO_SHELL=1`, `NO_TMUX=1`, `NO_FONT=1`.
</details>

### Docker — disposable, batteries-included

A thin Debian-slim image with Neovim + this config, plus a `zsh` (oh-my-zsh, autosuggestions, syntax-highlighting, **big persistent history**), `tmux`, `ripgrep`, the silver searcher (`ag`) and `fd`. The C toolchain and the `tree-sitter` CLI are baked in so parsers build on first launch.

```bash
docker compose build              # build once
docker compose run --rm dev       # zsh shell; your current dir is mounted at /work
docker compose run --rm dev nvim  # straight into Neovim
```

Or with plain Docker:

```bash
docker build -t neo-nvim .
docker run -it --rm -v "$PWD:/work" neo-nvim
```

Plugin data and shell history are kept in named volumes, so nothing re-installs and your history survives restarts.

---

## What's inside

- **LSP** via mason + nvim-lspconfig — `ruby_lsp` (gem), `jedi_language_server` (python) — both Node-free, auto-installed on first launch
- **Completion**: [blink.cmp](https://github.com/saghen/blink.cmp) (LSP, path, snippets, buffer + cmdline) — ships a prebuilt Rust binary
- **Formatting on save**: [conform.nvim](https://github.com/stevearc/conform.nvim) — `stylua` (lua), `rubocop` (ruby), `black` (python). JS/TS/JSON/HTML/CSS/SCSS/ERB/Slim are formatted dependency-free via Treesitter re-indent ([`lua/config/tsformat.lua`](lua/config/tsformat.lua)) — indentation + whitespace only, no external tool
- **Treesitter** highlighting (incl. js/ts/tsx/html/css/scss/erb/slim) + `nvim-ts-autotag`
- **Fuzzy find**: telescope · **Git**: fugitive + gitsigns · **Nav**: harpoon
- **UI**: catppuccin, lualine, indent-blankline, colorizer
- **Terminal**: plugin-free toggleable float/split terminal that keeps its session alive when hidden (`<leader>tt` / `<leader>ts`)
- **Neovide**: GUI tuning with [blurred floating windows](https://neovide.dev/features.html#blurred-floating-windows), shadows and cursor animations (only applied when run inside Neovide)

## Tests

Headless feature tests cover plugin registration, keymaps, options, external tools and the LSP/format wiring:

```bash
tests/run.sh
```

CI runs them on every push/PR both natively on Ubuntu and inside the Docker image (`.github/workflows/ci.yml`). Plugin versions are bumped weekly via an automated PR (`update-plugins.yml`); GitHub Actions and the Docker base image are kept current by Dependabot.

## Fonts

The installer sets up **JetBrainsMono Nerd Font** automatically (the icon font the UI and Neovide expect). After install, point your **terminal emulator** at `JetBrainsMono Nerd Font`; Neovide picks it up on its own. Skip the font install with `NO_FONT=1`.

Manual install, if you skipped it:

```bash
# Linux — per-user, no root
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -o /tmp/JBM.zip
unzip -o /tmp/JBM.zip -d ~/.local/share/fonts/JetBrainsMonoNerdFont && fc-cache -f

# macOS
brew install --cask font-jetbrains-mono-nerd-font
```

## Keymaps

Leader is `<Space>`. Press `<leader>t` (Telescope keymaps) to browse everything; LSP maps (`gd`, `gr`, `K`, `<leader>ca`, `<leader>rn`, …) are active in buffers with an attached language server.

See the [Cheatsheet](CHEATSHEET.md) for a sectioned list of useful keymaps and commands.
