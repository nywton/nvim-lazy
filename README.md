# Neovim Config

[![CI](https://github.com/nywton/nvim-lazy/actions/workflows/ci.yml/badge.svg)](https://github.com/nywton/nvim-lazy/actions/workflows/ci.yml)

A minimal, **Node-free**, near-zero-plugin Lua config built on [lazy.nvim](https://github.com/folke/lazy.nvim). Runs on **Ubuntu/Debian, macOS**, and in a **Docker** container.

Requires Neovim **0.12.0+** (nvim-treesitter's `main` branch needs it).

> **Two plugins, full stop:** `nvim-treesitter` (highlighting) and `catppuccin` (colorscheme — the one thing with no comparable built-in equivalent). Everything else — file/text search, git, the statusline, the terminal — is plain Lua over Neovim core plus two external CLI tools (`ripgrep`, `fzf`). No LSP, no ctags, no format-on-save, no completion plugin, no Mason.

---

## Requirements

The one-command installer and the Docker image (both under [Quick start](#quick-start)) set all of this up for you. This list matters only if you install **manually** or onto an unusual environment.

### Required

| Dependency | Why |
|---|---|
| **Neovim 0.12.0+** | nvim-treesitter `main` branch hard-errors below 0.12. |
| **git, curl, unzip, tar** | Bootstrapping lazy.nvim, cloning plugins, downloading release binaries. |
| **C compiler** — `build-essential` (gcc/`cc`) | Treesitter parsers are compiled locally from C. |
| **[`tree-sitter` CLI](https://github.com/tree-sitter/tree-sitter)** (single Rust binary) | nvim-treesitter `main` shells out to `tree-sitter build` to compile every parser. **Without it, no parser installs.** Get it from the [releases](https://github.com/tree-sitter/tree-sitter/releases), `brew install tree-sitter`, or `cargo install tree-sitter-cli`. |
| **ripgrep** (`rg`) | Backs every search: `:grep`, `<leader>s`, and the `gd`/`gi`/`gr` code-navigation fallback (`lua/finder/*.lua`). |
| **fzf** | The interactive picker for file finding (`<C-p>`) and code navigation (`gd`/`gi`/`gr`), run inside a terminal buffer — see `lua/finder/files.lua` and `lua/finder/grep.lua`. |
| **A UTF-8 locale** (e.g. `en_US.UTF-8`) | Neovim's `:checkhealth` errors without one; unicode UI glyphs need it. |

### Recommended

| Dependency | Why |
|---|---|
| **System clipboard tool** | The `"+`/`"*` registers. `xclip` or `wl-clipboard` on Linux; built in on macOS (`pbcopy`); auto-wired on WSL (`clip.exe`); falls back to OSC 52 over SSH with neither. |
| **A [Nerd Font](#fonts)** | Icons in the terminal UI. Installed automatically (JetBrainsMono Nerd Font); set your terminal to use it. |

### Installed automatically by the installer — nothing to do

- **Shell** — `zsh` + [oh-my-zsh](https://ohmyz.sh) + `zsh-autosuggestions` + `zsh-syntax-highlighting`, wired into `~/.zshrc` via a guarded block. Skip with `NO_SHELL=1`. (Setting zsh as your login shell is left to you: `chsh -s "$(command -v zsh)"`.)
- **Plugins** — lazy.nvim on first launch, pinned to `lazy-lock.json` (just `nvim-treesitter` + `catppuccin`).

### Explicitly *not* required

- **Node.js / npm** — never installed or run.
- **Ruby / rbenv, or any language server** — there's no LSP in this config. `gd`/`gi`/`gr` are a bare ripgrep+fzf picker instead (see [What's inside](#whats-inside)).
- **stylua / black / rubocop, or any formatter** — nothing formats on save. Format manually with whatever tool you like, or add it back yourself if you want it.
- **ctags** — removed entirely; no tags file is generated or consumed.

---

## Quick start

### Local (Ubuntu / Debian / macOS) — one command

Installs Neovim (latest stable, 0.12+), the required tools, clones this repo to `~/.config/nvim`, and syncs the two plugins. **Re-run it any time to update everything.**

```bash
curl -fsSL https://raw.githubusercontent.com/nywton/nvim-lazy/main/scripts/install.sh | bash
```

Then just run `nvim`.

Already cloned? Update in place:

```bash
~/.config/nvim/scripts/install.sh        # or: cd ~/.config/nvim && git pull && nvim "+Lazy! sync" +qa
```

<details>
<summary>What the script installs</summary>

- **Neovim** — latest stable from the official GitHub release (tarball on Linux, brew on macOS)
- **System tools** — `git curl unzip`, a C compiler (`build-essential`/Xcode CLT), the [`tree-sitter` CLI](https://github.com/tree-sitter/tree-sitter) that compiles Treesitter parsers, `ripgrep`, `fzf`, and `xclip`/`wl-clipboard` (system clipboard)
- **Locale** — generates `en_US.UTF-8` if missing (Neovim's `:checkhealth` errors without a UTF-8 locale)
- **Shell** — `zsh` + [oh-my-zsh](https://ohmyz.sh), `zsh-autosuggestions`, `zsh-syntax-highlighting`; wired into `~/.zshrc` via a single guarded block (your existing `~/.zshrc` is never overwritten)
- **tmux** — `tmux`, a dependency-free `~/.config/tmux/stats.sh`, and a Catppuccin Mocha `~/.tmux.conf` (pure tmux, no TPM/plugins). Single status line at the bottom: session name on the left, window list centered, and on the right — machine │ user │ a plain-ASCII, color-coded (green/yellow/red by load) system navbar (CPU/RAM/DISK/NET, plus GPU and a Docker summary — containers, CPU%, mem, disk, IO — when either is detected) │ IP │ clock. Labels are plain ASCII rather than Nerd Font icons so they render in any terminal without a special font. To add a stat, edit `config/tmux/stats.sh` and re-run the installer — no `tmux.conf` changes needed. The base config is written only if you don't already have one; the status bar is added/refreshed on **every** run via a guarded managed block, so re-running picks it up even on top of an existing config. Skip with `NO_TMUX=1`
- **Font** — JetBrainsMono Nerd Font into `~/.local/share/fonts` (Linux) or via brew cask (macOS); skip with `NO_FONT=1`

Every step is **idempotent** — re-run any time to update; already-installed pieces are just checked/updated.

On a **headless server** (Linux with no `$DISPLAY`/`$WAYLAND_DISPLAY` — e.g. Ubuntu over SSH) the script automatically skips the GUI extras: kitty, the Nerd Font, and the `xclip`/`wl-clipboard`/`fontconfig` packages. Force this mode with `SERVER=1`, or opt back into the GUI bits with `SERVER=0`. Clipboard still works over SSH: Neovim falls back to [OSC 52](https://neovim.io/doc/user/provider.html#clipboard-osc52) (yanks land in your *local* clipboard), and the installer's tmux block sets `set-clipboard on` so it passes through tmux — your local terminal just needs OSC 52 support (kitty, iTerm2, WezTerm, Ghostty, Windows Terminal).

Override defaults with env vars: `REPO_URL`, `NVIM_DIR`, `NO_SYNC=1`, `NO_SHELL=1`, `NO_TMUX=1`, `NO_FONT=1`, `NO_KITTY=1`, `SERVER=1`.
</details>

### Docker — disposable, batteries-included

A thin Debian-slim image with Neovim + this config, plus `zsh` (oh-my-zsh, autosuggestions, syntax-highlighting, **big persistent history**), `tmux`, `ripgrep` and `fzf`. The C toolchain and the `tree-sitter` CLI are baked in so parsers build on first launch.

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

- **Treesitter** highlighting (incl. json/js/ts/tsx/yaml/html/css/scss/erb/slim/bash/dockerfile/ruby/python) — the one plugin that manages parser installs; highlighting itself is Neovim core
- **Completion**: Neovim 0.12's built-in `'autocomplete'` (buffer/window words — no LSP source, no completion plugin)
- **Code navigation** (`gd`/`gi`/`gr`): no LSP, no ctags — ripgrep searches the word under the cursor repo-wide, `fzf` picks the match (`lua/finder/grep.lua`). All three land on the same picker since there's no server to disambiguate definition/implementation/references.
- **File finding** (`<C-p>`): `rg --files` piped through `fzf` in a terminal buffer (`lua/finder/files.lua`)
- **Content search** (`<leader>s`): ripgrep straight into the quickfix list, navigated with `<C-k>`/`<C-j>`
- **Quickset** (`<leader>a` add / `<C-e>` menu / `<C-h>`,`<C-t>` prev-next): a ~30-line harpoon-style hand-picked file list, session-local, no persistence
- **Git**: raw `git` + scratch buffers, no fugitive/gitsigns/diffview — `<leader>gg` (status, with `<CR>`/`s`/`u` to open/stage/unstage), `<leader>gd` (diff), `<leader>gb` (toggle inline current-line blame, virtual text), `<leader>gB` (full-file blame history, scratch buffer), `<leader>gl` (log), `]c`/`[c` (repo-wide uncommitted-hunk navigation). Anything interactive/stateful (commit, push, pull, rebase) — use the terminal (`<leader>tt`) directly.
- **UI**: catppuccin (colorscheme) + a built-in `vim.o.statusline` (mode, branch, diagnostics count, filename, filetype, clock, position) — no lualine
- **Terminal**: plugin-free toggleable float/split terminal that keeps its session alive when hidden (`<leader>tt` / `<leader>ts`)
- **Neovide**: GUI tuning with [blurred floating windows](https://neovide.dev/features.html#blurred-floating-windows), shadows and cursor animations (only applied when run inside Neovide)

Not in this config, by design: LSP, ctags, format-on-save, a completion plugin, Mason, telescope, fugitive/gitsigns/diffview, harpoon, lualine, autopairs, ts-autotag. See the commit history around the `nvim2` refactor for the reasoning behind each removal.

## Tests

Headless feature tests cover plugin registration, keymaps, options, and required external tools:

```bash
tests/run.sh
```

CI runs them on every push/PR both natively on Ubuntu and inside the Docker image (`.github/workflows/ci.yml`). Plugin versions (just `nvim-treesitter` + `catppuccin`) are bumped weekly via an automated PR (`update-plugins.yml`); GitHub Actions and the Docker base image are kept current by Dependabot.

## Fonts

The installer sets up **JetBrainsMono Nerd Font** automatically. After install, point your **terminal emulator** at `JetBrainsMono Nerd Font`. Skip the font install with `NO_FONT=1`.

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

Leader is `<Space>`. `:map <leader>` / `:verbose map <lhs>` show what's bound; the source under `lua/core/keymaps/`, `lua/finder/`, `lua/git/` is the ground truth. Highlights:

| Key | Action |
|---|---|
| `<C-p>` | Find files (rg + fzf) |
| `<leader>s` | Live grep → quickfix (`<C-k>`/`<C-j>` to navigate) |
| `gd` / `gi` / `gr` | Go to word occurrence (rg + fzf) |
| `<leader>gg` | Git status (scratch buffer: `<CR>` open, `s` stage, `u` unstage) |
| `<leader>gd` / `gl` | Git diff / log |
| `<leader>gb` / `gB` | Toggle inline current-line blame / full-file blame history |
| `]c` / `[c` | Next/previous uncommitted hunk, repo-wide |
| `<leader>a` / `<C-e>` / `<C-h>` / `<C-t>` | Quickset: add / menu / prev / next |
| `<leader>tt` / `<leader>ts` | Toggle floating / split terminal |
| `<leader>e` | Toggle netrw (built-in file explorer) |
| `<leader>b` | Switch buffer |
