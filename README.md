# Neovim Config

[![CI](https://github.com/nywton/nvim-lazy/actions/workflows/ci.yml/badge.svg)](https://github.com/nywton/nvim-lazy/actions/workflows/ci.yml)

A minimal, **Node-free**, **zero-plugin** Lua config. No plugin manager, no lockfile, nothing to bootstrap — just Neovim core plus a couple of external CLI tools for search. Runs on **Ubuntu/Debian, macOS**, and in **Docker**.

> **Zero plugins, full stop:** no plugin manager, no colorscheme plugin, no treesitter plugin — just Neovim core (built-in `habamax` colorscheme, built-in `:syntax` highlighting). No LSP, no ctags, no format-on-save, no completion plugin, no Mason.

Requires **Neovim 0.12.0+** (built-in `'autocomplete'` needs it).

---

## Requirements

| Tool | Why |
|---|---|
| **Neovim 0.12.0+** | Built-in `'autocomplete'` is this config's only completion source. |
| **git** | Backs the git integration (`lua/git/*.lua`) and clones this repo. |
| **ripgrep** (`rg`) | Every search: `:grep`, `<leader>s`, and the `gd`/`gi`/`gr` navigation fallback. |
| **fzf** | The interactive picker for file finding (`<C-p>`) and code navigation. |
| **curl, unzip, tar** | Only needed to download Neovim/the Nerd Font — skip if you install those another way. |
| **A UTF-8 locale** | `:checkhealth` errors without one. |

Recommended: a clipboard tool (`xclip`/`wl-clipboard` on Linux, built-in on macOS) for the `"+`/`"*` registers, and a [Nerd Font](#fonts) for terminal-UI icons.

Not required: a plugin manager, Node.js/npm, Ruby/rbenv, any LSP or formatter, ctags.

---

## Install

### Script — one command

Installs Neovim, the tools above, and clones this repo to `~/.config/nvim`. Idempotent — re-run any time to update everything.

```bash
curl -fsSL https://raw.githubusercontent.com/nywton/nvim-lazy/main/scripts/install.sh | bash
```

Already cloned? `~/.config/nvim/scripts/install.sh` (or just `git pull`) updates in place.

<details>
<summary>What it sets up, and how to configure it</summary>

- **Neovim** — latest stable from the official GitHub release
- **ripgrep, fzf, git, curl, unzip** — via apt/brew
- **zsh** + oh-my-zsh + autosuggestions + syntax-highlighting, wired into `~/.zshrc` — skip with `NO_SHELL=1`
- **tmux** + a dependency-free status line (`config/tmux/stats.sh`) — skip with `NO_TMUX=1`
- **JetBrainsMono Nerd Font** — skip with `NO_FONT=1`
- A UTF-8 locale, generated if missing

On a headless server (no `$DISPLAY`/`$WAYLAND_DISPLAY`) it auto-skips GUI extras (kitty, the font, clipboard packages); force with `SERVER=1`, opt back in with `SERVER=0`. Clipboard still works over SSH via [OSC 52](https://neovim.io/doc/user/provider.html#clipboard-osc52).

Other env vars: `REPO_URL`, `NVIM_DIR`, `NO_KITTY=1`.
</details>

### Manual — step by step

1. **Install Neovim 0.12+.** Get the latest stable release for your platform from the [Neovim releases page](https://github.com/neovim/neovim/releases), or `brew install neovim` on macOS.
2. **Install the required tools:**
   ```bash
   # Debian/Ubuntu
   sudo apt-get install git ripgrep fzf curl unzip

   # macOS
   brew install git ripgrep fzf curl
   ```
3. **Clone this repo to `~/.config/nvim`** (back up any existing config first):
   ```bash
   mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null
   git clone https://github.com/nywton/nvim-lazy ~/.config/nvim
   ```
4. **(Optional) Install a [Nerd Font](#fonts)** for terminal-UI icons.
5. Launch with `nvim`. No further setup steps — no plugin sync, nothing to build.

### Docker — disposable, batteries-included

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

Shell history is kept in a named volume, so it survives restarts.

---

## What's inside

- **Syntax highlighting**: Neovim's built-in legacy `:syntax` engine covers most filetypes; lua/vim/vimdoc/markdown get native treesitter highlighting out of the box — no plugin either way
- **Completion**: Neovim 0.12's built-in `'autocomplete'` (buffer/window words — no LSP source, no completion plugin)
- **Code navigation** (`gd`/`gi`/`gr`): no LSP, no ctags — ripgrep searches the word under the cursor repo-wide, `fzf` picks the match
- **File finding** (`<C-p>`): `rg --files` piped through `fzf` in a terminal buffer
- **Content search** (`<leader>s`): ripgrep straight into the quickfix list, navigated with `<C-k>`/`<C-j>`
- **Quickset** (`<leader>a` add / `<C-e>` menu / `<C-h>`,`<C-t>` prev-next): a ~30-line harpoon-style hand-picked file list, session-local
- **Git**: raw `git` + scratch buffers, no fugitive/gitsigns/diffview — `<leader>gg` (status), `<leader>gd` (diff), `<leader>gb`/`gB` (blame), `<leader>gl` (log), `]c`/`[c` (hunk navigation). Interactive/stateful commands (commit, push, pull, rebase) — use the terminal (`<leader>t`) directly.
- **UI**: habamax (built-in colorscheme, transparent background) + a built-in `vim.o.statusline` — no lualine
- **Terminal**: plugin-free toggleable floating terminal (`<leader>t`); `<Esc><Esc>` hides it, and the shell exiting closes it automatically
- **Neovide**: GUI tuning with blurred floating windows, shadows, and cursor animations (only applied when run inside Neovide)

Not in this config, by design: a plugin manager, treesitter, LSP, ctags, format-on-save, a completion plugin, Mason, telescope, fugitive/gitsigns/diffview, harpoon, lualine, autopairs, ts-autotag.

## Tests

```bash
tests/run.sh
```

CI runs them on every push/PR, natively on Ubuntu and inside the Docker image (`.github/workflows/ci.yml`). GitHub Actions and the Docker base image are kept current by Dependabot.

## Fonts

The installer sets up **JetBrainsMono Nerd Font** automatically (`NO_FONT=1` to skip). Point your **terminal emulator** at it afterward. Manual install:

```bash
# Linux — per-user, no root
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -o /tmp/JBM.zip
unzip -o /tmp/JBM.zip -d ~/.local/share/fonts/JetBrainsMonoNerdFont && fc-cache -f

# macOS
brew install --cask font-jetbrains-mono-nerd-font
```

## Keymaps

Leader is `<Space>`. `:map <leader>` / `:verbose map <lhs>` show what's bound; the source under `lua/core/keymaps/`, `lua/finder/`, `lua/git/` is the ground truth.

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
| `<leader>t` | Toggle/switch floating terminal (`<Esc><Esc>` to hide) |
| `<leader>e` | Toggle netrw (built-in file explorer) |
| `<leader>b` | Switch buffer |
