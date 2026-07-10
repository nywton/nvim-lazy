#!/usr/bin/env bash
#
# nvim-lazy installer / updater  —  Ubuntu/Debian + macOS
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/nywton/nvim-lazy/main/scripts/install.sh | bash
#
# Re-running this script UPDATES everything (Neovim, system tools, the config
# repo and all plugins). It is safe to run as often as you like.
#
# Overridable via environment variables:
#   REPO_URL       git remote to clone           (default: https://github.com/nywton/nvim-lazy)
#   NVIM_DIR       where the config lives         (default: $HOME/.config/nvim)
#   NO_SYNC=1      skip the headless plugin sync  (default: unset → sync runs)
#   NO_SHELL=1     skip zsh/oh-my-zsh setup       (default: unset → installs)
#   NO_FONT=1      skip the Nerd Font install     (default: unset → installs)
#   NO_TMUX=1      skip tmux + ~/.tmux.conf setup (default: unset → installs)
#   NO_KITTY=1     skip kitty terminal setup      (default: unset → prompts)
#   SERVER=1       headless-server mode: skip GUI extras (kitty, Nerd Font,
#                  X/Wayland clipboard tools). Auto-detected on Linux when no
#                  $DISPLAY/$WAYLAND_DISPLAY is set; force off with SERVER=0.
#
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/nywton/nvim-lazy}"
NVIM_DIR="${NVIM_DIR:-$HOME/.config/nvim}"

# ----------------------------------------------------------------------------
# pretty logging
# ----------------------------------------------------------------------------
if [ -t 1 ]; then
  BLUE=$'\033[34m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  BLUE=""; GREEN=""; YELLOW=""; RED=""; BOLD=""; RESET=""
fi
info()  { printf '%s==>%s %s\n' "$BLUE$BOLD" "$RESET" "$*"; }
ok()    { printf '%s ok %s %s\n' "$GREEN$BOLD" "$RESET" "$*"; }
warn()  { printf '%swarn%s %s\n' "$YELLOW$BOLD" "$RESET" "$*"; }
die()   { printf '%serr %s %s\n' "$RED$BOLD" "$RESET" "$*" >&2; exit 1; }

# Ask the user a question on the controlling terminal and echo their answer.
# Works even when this script is piped via `curl | bash` (stdin is the script,
# so we read from /dev/tty). When no terminal is attached (CI, fully unattended
# runs), the default ($2) is returned without blocking.
prompt() {
  local question="$1" default="$2" answer=""
  if [ -r /dev/tty ]; then
    printf '%s' "$question" > /dev/tty
    IFS= read -r answer < /dev/tty || answer=""
  fi
  printf '%s' "${answer:-$default}"
}

# Run a command with sudo only when we are not already root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 && SUDO="sudo"
fi

# ----------------------------------------------------------------------------
# OS / arch detection
# ----------------------------------------------------------------------------
OS="$(uname -s)"
ARCH="$(uname -m)"

# ----------------------------------------------------------------------------
# Headless-server detection — on a display-less Linux box (typical Ubuntu
# server) the GUI bits are dead weight: kitty, the Nerd Font and the X/Wayland
# clipboard tools all need a display. Auto-detected from $DISPLAY /
# $WAYLAND_DISPLAY; force with SERVER=1, opt back in with SERVER=0.
# ----------------------------------------------------------------------------
HEADLESS=""
if [ "${SERVER:-}" = "1" ]; then
  HEADLESS=1
elif [ "${SERVER:-}" != "0" ] && [ "$OS" = "Linux" ] \
  && [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  HEADLESS=1
fi
if [ -n "$HEADLESS" ]; then
  NO_KITTY=1
  NO_FONT=1
fi

# ----------------------------------------------------------------------------
# Neovim  (latest stable, from the official GitHub release tarball/brew)
# ----------------------------------------------------------------------------
install_nvim_linux() {
  case "$ARCH" in
    x86_64)        local asset="nvim-linux-x86_64.tar.gz" ;;
    aarch64|arm64) local asset="nvim-linux-arm64.tar.gz"  ;;
    *) die "Unsupported architecture: $ARCH" ;;
  esac

  local latest
  latest="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f 4)"
  [ -n "$latest" ] || die "could not resolve latest Neovim release"
  info "Installing Neovim $latest ($asset)"

  # NB: clean up explicitly rather than via `trap ... RETURN`. A RETURN trap is
  # global in bash, so it would also fire when the *caller* returns — by then
  # $tmp is out of scope and `set -u` aborts with "tmp: unbound variable".
  local tmp; tmp="$(mktemp -d)"
  curl -fL "https://github.com/neovim/neovim/releases/download/${latest}/${asset}" \
    -o "${tmp}/nvim.tar.gz"
  tar -xzf "${tmp}/nvim.tar.gz" -C "${tmp}"

  $SUDO rm -rf /opt/neovim
  $SUDO mv "${tmp}"/nvim-linux-* /opt/neovim
  $SUDO ln -sf /opt/neovim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp"
  ok "$(nvim --version | head -n1)"
}

# ----------------------------------------------------------------------------
# fzf  (required by the finder: lua/finder/files.lua and lua/finder/grep.lua's
# goto_word() pipe ripgrep through it). Core dependency, not a shell nicety —
# installed unconditionally, independent of NO_SHELL.
# ----------------------------------------------------------------------------
install_fzf() {
  command -v fzf >/dev/null 2>&1 && { ok "fzf present"; return; }
  info "Installing fzf"
  if [ "$OS" = "Darwin" ]; then
    brew install fzf || true
  else
    $SUDO apt-get install -y --no-install-recommends fzf 2>/dev/null \
      || { clone_or_update https://github.com/junegunn/fzf.git "$HOME/.fzf" \
           && "$HOME/.fzf/install" --key-bindings --completion --no-update-rc >/dev/null; }
  fi
}

install_deps_linux() {
  command -v apt-get >/dev/null 2>&1 || die "this script supports apt-based distros (Ubuntu/Debian). Install deps manually otherwise."
  info "Installing system packages via apt"
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -y
  # No nodejs/npm on purpose — this config is Node-free. build-essential
  # supplies the C compiler the tree-sitter CLI (installed below) shells out
  # to when building parsers. ripgrep backs the finder (lua/finder/*.lua) and
  # :grep. xclip / wl-clipboard back the "+/"* registers (system clipboard) so
  # :checkhealth doesn't warn "No clipboard tool found". locales lets us
  # generate a UTF-8 locale below. GUI-only packages (clipboard tools need an
  # X/Wayland display, fontconfig only serves the Nerd Font) are dropped in
  # headless-server mode.
  local gui_pkgs="xclip wl-clipboard fontconfig"
  [ -n "$HEADLESS" ] && gui_pkgs=""
  $SUDO apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip tar locales \
    build-essential ripgrep \
    $gui_pkgs
  # Ensure a UTF-8 locale exists (Neovim's :checkhealth errors without one).
  if command -v locale-gen >/dev/null 2>&1; then
    $SUDO sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
    $SUDO locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
  fi
  # Generating the locale isn't enough — LANG must also point at it, or
  # minimal servers (LANG unset) still hit the checkhealth UTF-8 ERROR.
  # update-locale persists it in /etc/default/locale for future SSH logins;
  # the export covers the rest of this script run (headless plugin sync).
  if ! locale 2>/dev/null | grep -qiE '^LANG=.*utf-?8'; then
    command -v update-locale >/dev/null 2>&1 && $SUDO update-locale LANG=en_US.UTF-8 2>/dev/null || true
    export LANG=en_US.UTF-8
  fi
  install_nvim_linux
  install_fzf
}

install_deps_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  info "Installing packages via Homebrew"
  # Node-free: no node here.
  # tree-sitter is the CLI that nvim-treesitter's `main` branch shells out to
  # when compiling parsers (`tree-sitter build`).
  brew install neovim git curl ripgrep fzf tree-sitter || true
  ok "$(nvim --version | head -n1)"
}

# ----------------------------------------------------------------------------
# tree-sitter CLI  (REQUIRED by nvim-treesitter `main`: parsers are built with
# `tree-sitter build`, not a bare C compiler). Idempotent: skips when already
# present. On Linux, tries apt first (Ubuntu 24.04+ ships tree-sitter-cli),
# then falls back to the prebuilt GitHub release binary. macOS uses brew above.
# ----------------------------------------------------------------------------
install_tree_sitter_cli() {
  # `tree-sitter build` (required by nvim-treesitter main) was added in v0.22.
  # If the binary exists but is too old, fall through to upgrade it.
  if command -v tree-sitter >/dev/null 2>&1 && tree-sitter build --help >/dev/null 2>&1; then
    ok "tree-sitter CLI present ($(tree-sitter --version 2>/dev/null || echo unknown))"
    return
  fi
  if command -v tree-sitter >/dev/null 2>&1; then
    warn "tree-sitter $(tree-sitter --version 2>/dev/null) is too old (needs >= 0.22 for 'tree-sitter build'); upgrading"
  fi

  if [ "$OS" = "Darwin" ]; then
    info "Installing tree-sitter CLI via Homebrew"
    brew install tree-sitter && ok "tree-sitter $(tree-sitter --version 2>/dev/null || echo installed)" \
      || warn "could not install tree-sitter via brew; install it manually"
    return
  fi

  # Try apt first, but only keep it if it's actually new enough: Ubuntu noble's
  # tree-sitter-cli package is stuck on 0.20.8 (pre-dates the `build` subcommand
  # added in v0.22), so `apt-get install` exits 0 yet leaves a non-functional
  # binary. Verify `tree-sitter build --help` before trusting it; otherwise fall
  # through to the GitHub release below.
  if command -v apt-get >/dev/null 2>&1 && apt-cache show tree-sitter-cli >/dev/null 2>&1; then
    info "Installing tree-sitter-cli via apt"
    if $SUDO apt-get install -y --no-install-recommends tree-sitter-cli \
      && tree-sitter build --help >/dev/null 2>&1; then
      ok "tree-sitter $(tree-sitter --version 2>/dev/null || echo installed)"
      return
    fi
    warn "apt's tree-sitter-cli $(tree-sitter --version 2>/dev/null || echo '(unknown)') is too old or failed to install; falling back to GitHub release"
  fi

  # Fall back to the prebuilt GitHub release binary (works on older Ubuntu too).
  case "$ARCH" in
    x86_64)        local ta="tree-sitter-linux-x64.gz" ;;
    aarch64|arm64) local ta="tree-sitter-linux-arm64.gz" ;;
    *) warn "no tree-sitter CLI build for $ARCH; treesitter parsers won't compile"; return ;;
  esac
  info "Installing tree-sitter CLI from GitHub release ($ta)"
  local tmp; tmp="$(mktemp -d)"
  if curl -fL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/${ta}" -o "${tmp}/ts.gz"; then
    gunzip -f "${tmp}/ts.gz"
    $SUDO install -m 0755 "${tmp}/ts" /usr/local/bin/tree-sitter
    ok "tree-sitter $(tree-sitter --version 2>/dev/null || echo installed)"
  else
    warn "could not download tree-sitter CLI; treesitter parsers won't compile until you install it"
  fi
  rm -rf "$tmp"
}

# ----------------------------------------------------------------------------
# JetBrainsMono Nerd Font  (the icon font the UI/Neovide expect — see
# lua/neovide.lua). Idempotent; skip with NO_FONT=1. Set your terminal
# emulator to use "JetBrainsMono Nerd Font" afterwards (Neovide picks it up
# automatically).
# ----------------------------------------------------------------------------
install_font() {
  [ "${NO_FONT:-}" = "1" ] && { warn "NO_FONT=1 → skipping Nerd Font install"; return; }

  if [ "$OS" = "Darwin" ]; then
    brew install --cask font-jetbrains-mono-nerd-font 2>/dev/null || true
    ok "JetBrainsMono Nerd Font (brew cask)"
    return
  fi

  if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    ok "JetBrainsMono Nerd Font present"
    return
  fi

  local dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  info "Installing JetBrainsMono Nerd Font"
  local tmp; tmp="$(mktemp -d)"
  if curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -o "${tmp}/font.zip"; then
    mkdir -p "$dir"
    unzip -o -q "${tmp}/font.zip" -d "$dir"
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$dir" >/dev/null 2>&1 || true
    ok "JetBrainsMono Nerd Font installed → $dir"
  else
    warn "could not download JetBrainsMono Nerd Font; install a Nerd Font manually for icons"
  fi
  rm -rf "$tmp"
}

# ----------------------------------------------------------------------------
# git clone OR fast-forward update — the idempotent building block used below.
# ----------------------------------------------------------------------------
clone_or_update() {
  local url="$1" dir="$2"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" pull --ff-only 2>/dev/null || true
  else
    git clone --depth=1 "$url" "$dir"
  fi
}

# ----------------------------------------------------------------------------
# Shell: zsh + oh-my-zsh + zsh-autosuggestions + zsh-syntax-highlighting.
# Idempotent: installs what's missing, updates what's present, and configures
# ~/.zshrc via a single guarded block (never clobbers your existing config).
# Skip entirely with NO_SHELL=1. (fzf itself is a core dependency, installed
# unconditionally by install_fzf — this only wires its zsh key-bindings.)
# ----------------------------------------------------------------------------
install_shell() {
  [ "${NO_SHELL:-}" = "1" ] && { warn "NO_SHELL=1 → skipping zsh/oh-my-zsh setup"; return; }

  # --- zsh ---
  if command -v zsh >/dev/null 2>&1; then
    ok "zsh present"
  else
    info "Installing zsh"
    if [ "$OS" = "Linux" ]; then $SUDO apt-get install -y --no-install-recommends zsh; else brew install zsh || true; fi
  fi

  # --- oh-my-zsh (KEEP_ZSHRC: don't let the installer rewrite ~/.zshrc) ---
  local ZSH_DIR="$HOME/.oh-my-zsh"
  if [ -d "$ZSH_DIR" ]; then
    info "Updating oh-my-zsh"
    git -C "$ZSH_DIR" pull --ff-only 2>/dev/null || true
  else
    info "Installing oh-my-zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
      || warn "oh-my-zsh install hit an error"
  fi

  # --- custom plugins ---
  local custom="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
  info "Installing/updating zsh plugins (autosuggestions, syntax-highlighting)"
  clone_or_update https://github.com/zsh-users/zsh-autosuggestions     "$custom/plugins/zsh-autosuggestions"
  clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting"

  # --- ~/.zshrc (guarded managed block, written once) ---
  local rc="$HOME/.zshrc"
  [ -e "$rc" ] || : > "$rc"
  if grep -q 'nvim-lazy shell setup' "$rc" 2>/dev/null; then
    ok ".zshrc already configured"
  else
    # Bootstrap oh-my-zsh sourcing only if the user has none yet.
    if ! grep -q 'oh-my-zsh.sh' "$rc" 2>/dev/null; then
      {
        printf '\nexport ZSH="$HOME/.oh-my-zsh"\n'
        printf 'ZSH_THEME="robbyrussell"\n'
        printf 'plugins=(git tmux)\n'
        printf 'source "$ZSH/oh-my-zsh.sh"\n'
      } >> "$rc"
    fi
    cat >> "$rc" <<'ZSHRC'

# >>> nvim-lazy shell setup >>>  (managed block — remove the whole block to undo)
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
source "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
# fzf key-bindings + completion (modern `fzf --zsh`, else the git-install file)
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then source <(fzf --zsh); elif [ -f ~/.fzf.zsh ]; then source ~/.fzf.zsh; fi
fi
export EDITOR=nvim VISUAL=nvim
alias vi=nvim vim=nvim
# zsh-syntax-highlighting MUST be sourced last
source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null
# <<< nvim-lazy shell setup <<<
ZSHRC
    ok "configured .zshrc"
  fi

  # Offer to make zsh the login shell, but never force it (needs a password).
  if [ "${SHELL:-}" != "$(command -v zsh 2>/dev/null)" ]; then
    info "zsh is not your default shell — set it with: chsh -s \"\$(command -v zsh)\""
  fi
}

# ----------------------------------------------------------------------------
# tmux + ~/.tmux.conf  (Catppuccin Mocha config — pure tmux, no TPM/plugins).
# Installs tmux (apt/brew), drops the status-bar stats helper at
# ~/.config/tmux/stats.sh, and writes ~/.tmux.conf ONLY when it does not
# already exist — an existing config is always left untouched. Idempotent and
# safe to re-run. Skip the whole step with NO_TMUX=1.
# ----------------------------------------------------------------------------
install_tmux() {
  [ "${NO_TMUX:-}" = "1" ] && { warn "NO_TMUX=1 → skipping tmux setup"; return; }

  # --- tmux ---
  if command -v tmux >/dev/null 2>&1; then
    ok "tmux present"
  else
    info "Installing tmux"
    if [ "$OS" = "Linux" ]; then
      $SUDO apt-get install -y --no-install-recommends tmux \
        || warn "could not install tmux via apt; install it manually"
    else
      brew install tmux || true
    fi
  fi

  # --- ~/.config/tmux/stats.sh — the status-bar stats helper (CPU/GPU/RAM/
  # DISK/NET/Docker). Copied from the repo (config/tmux/stats.sh) so it's a
  # single source of truth — edit it there, re-run the installer anywhere to
  # pick up the change. Always (re)copied since it's a generated helper, not
  # user-editable config.
  local stats="$HOME/.config/tmux/stats.sh"
  if [ -f "$NVIM_DIR/config/tmux/stats.sh" ]; then
    info "Writing $stats"
    mkdir -p "$(dirname "$stats")"
    cp "$NVIM_DIR/config/tmux/stats.sh" "$stats"
    chmod +x "$stats"
    ok "stats helper → $stats"
  else
    warn "config/tmux/stats.sh not found in $NVIM_DIR; skipping stats helper deploy"
  fi

  # --- ~/.tmux.conf ---
  # Base config: copied from the repo (config/tmux/tmux.conf) ONLY when
  # absent — an existing config is never clobbered. The status bar is applied
  # separately as a guarded managed block (below) so it's added/refreshed on
  # EVERY run — even on top of a pre-existing or hand-edited config. tmux's
  # `set -g` is last-wins, so the appended block overrides any earlier
  # status-right.
  local rc="$HOME/.tmux.conf"
  if [ -e "$rc" ]; then
    ok ".tmux.conf already exists → leaving the base config untouched"
  elif [ -f "$NVIM_DIR/config/tmux/tmux.conf" ]; then
    info "Writing $rc"
    cp "$NVIM_DIR/config/tmux/tmux.conf" "$rc"
    ok "configured .tmux.conf"
  else
    warn "config/tmux/tmux.conf not found in $NVIM_DIR; skipping base config deploy"
  fi

  # --- status bar (guarded managed block — added/refreshed every run) ---
  # Idempotent: strip any previous block, then append the current one (from
  # config/tmux/statusbar.conf). tmux applies `set -g` last-wins, so this
  # overrides whatever status-right the rest of the file (yours or ours) set.
  # Remove the whole block to undo.
  if [ -f "$NVIM_DIR/config/tmux/statusbar.conf" ] && [ -e "$rc" ]; then
    info "Applying tmux status bar (managed block)"
    local tmp; tmp="$(mktemp)"
    # Strip any previous managed block, then drop trailing blank lines so the
    # single blank separator we re-add below can't accumulate across re-runs.
    awk '
      /^# >>> nvim-lazy tmux stats >>>/ { skip = 1 }
      !skip { lines[++n] = $0 }
      /^# <<< nvim-lazy tmux stats <<</ { skip = 0 }
      END {
        while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
        for (i = 1; i <= n; i++) print lines[i]
      }
    ' "$rc" > "$tmp"
    {
      printf '\n# >>> nvim-lazy tmux stats >>>  (managed block — remove the whole block to undo)\n'
      cat "$NVIM_DIR/config/tmux/statusbar.conf"
      printf '# <<< nvim-lazy tmux stats <<<\n'
    } >> "$tmp"
    mv "$tmp" "$rc"
    ok "status bar applied → $rc"
  fi

  # Live-reload if we're running inside a tmux session.
  if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
    tmux source-file "$rc" >/dev/null 2>&1 && ok "reloaded running tmux config" || true
  fi
}

# ----------------------------------------------------------------------------
# kitty terminal  —  optional; prompts before installing unless NO_KITTY is set.
# Installs kitty, drops config/kitty.conf from this repo into ~/.config/kitty/,
# and sets kitty as the default x-terminal-emulator (Linux only; macOS users
# set the default terminal in System Settings → Desktop & Dock). Skip with
# NO_KITTY=1 or by answering "n" at the prompt.
# ----------------------------------------------------------------------------
install_kitty() {
  [ "${NO_KITTY:-}" = "1" ] && { warn "NO_KITTY=1 → skipping kitty setup"; return; }

  local answer
  answer="$(prompt "Install and configure kitty terminal? [y/N] " n)"
  case "$answer" in
    y|Y|yes|Yes|YES) ;;
    *) warn "skipping kitty setup"; return ;;
  esac

  # --- install ---
  if command -v kitty >/dev/null 2>&1; then
    ok "kitty present ($(kitty --version 2>/dev/null | head -n1))"
  else
    info "Installing kitty"
    if [ "$OS" = "Darwin" ]; then
      brew install --cask kitty || { warn "could not install kitty via brew; install it from https://sw.kovidgoyal.net/kitty/"; return; }
    else
      # Official curl installer — the only reliable cross-distro method.
      curl -fL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
      # Expose the binary on PATH (the installer puts it in ~/.local/kitty.app on Linux).
      if [ -x "$HOME/.local/kitty.app/bin/kitty" ]; then
        $SUDO ln -sf "$HOME/.local/kitty.app/bin/kitty" /usr/local/bin/kitty 2>/dev/null \
          || { mkdir -p "$HOME/.local/bin" && ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"; }
      fi
    fi
    ok "kitty $(kitty --version 2>/dev/null | head -n1)"
  fi

  # --- config ---
  local src="$NVIM_DIR/config/kitty.conf"
  local dst="$HOME/.config/kitty/kitty.conf"
  if [ -f "$src" ]; then
    mkdir -p "$HOME/.config/kitty"
    if [ -f "$dst" ] && ! grep -q 'nvim-lazy' "$dst" 2>/dev/null; then
      local backup="${dst}.bak.$(date +%Y%m%d%H%M%S 2>/dev/null || echo manual)"
      warn "existing kitty.conf detected — backing up to $backup"
      cp "$dst" "$backup"
    fi
    cp "$src" "$dst"
    ok "kitty config → $dst"
  else
    warn "config/kitty.conf not found in $NVIM_DIR; skipping config deploy"
  fi

  # --- set as default terminal (Linux only) ---
  if [ "$OS" = "Linux" ]; then
    local kitty_bin
    kitty_bin="$(command -v kitty 2>/dev/null || echo "")"
    if [ -n "$kitty_bin" ] && command -v update-alternatives >/dev/null 2>&1; then
      $SUDO update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$kitty_bin" 50 2>/dev/null || true
      $SUDO update-alternatives --set x-terminal-emulator "$kitty_bin" 2>/dev/null \
        && ok "kitty set as default x-terminal-emulator" \
        || warn "could not set kitty as default terminal; run: sudo update-alternatives --config x-terminal-emulator"
    fi

    # Desktop entry — lets GNOME/KDE app launchers and file managers open kitty.
    local desktop_src="$HOME/.local/kitty.app/share/applications/kitty.desktop"
    local desktop_dst="$HOME/.local/share/applications/kitty.desktop"
    if [ -f "$desktop_src" ]; then
      cp "$desktop_src" "$desktop_dst" 2>/dev/null || true
    fi
    # GNOME: set default terminal via gsettings if available.
    if command -v gsettings >/dev/null 2>&1; then
      gsettings set org.gnome.desktop.default-applications.terminal exec kitty 2>/dev/null \
        && ok "set kitty as GNOME default terminal" || true
    fi
  else
    info "macOS: set kitty as your default terminal in System Settings → Desktop & Dock → Default terminal app"
  fi
}

# ----------------------------------------------------------------------------
# the config repo
# ----------------------------------------------------------------------------
setup_config() {
  if [ -d "$NVIM_DIR/.git" ]; then
    info "Updating existing config in $NVIM_DIR"
    git -C "$NVIM_DIR" pull --ff-only || warn "could not fast-forward $NVIM_DIR (local changes?)"
  elif [ -e "$NVIM_DIR" ]; then
    local backup="${NVIM_DIR}.bak.$(date +%Y%m%d%H%M%S 2>/dev/null || echo manual)"
    warn "$NVIM_DIR exists and is not this repo — backing up to $backup"
    mv "$NVIM_DIR" "$backup"
    git clone "$REPO_URL" "$NVIM_DIR"
  else
    info "Cloning $REPO_URL → $NVIM_DIR"
    mkdir -p "$(dirname "$NVIM_DIR")"
    git clone "$REPO_URL" "$NVIM_DIR"
  fi
}

# ----------------------------------------------------------------------------
# plugins (headless) — installs/updates to the versions in lazy-lock.json
# ----------------------------------------------------------------------------
sync_plugins() {
  [ "${NO_SYNC:-}" = "1" ] && { warn "NO_SYNC=1 → skipping plugin sync"; return; }
  info "Syncing plugins (headless)…"
  nvim --headless "+Lazy! sync" +qa || warn "plugin sync hit an error — open nvim and run :Lazy"
  # nvim-treesitter `main` branch has no :TSUpdateSync, and :TSUpdate is async
  # (it would return before downloads finish under --headless). Install the
  # configured parsers synchronously via the Lua API; the list comes from the
  # same module the plugin uses (lua/core/treesitter_parsers.lua).
  info "Installing treesitter parsers (headless)…"
  nvim --headless \
    "+lua require('nvim-treesitter').install(require('core.treesitter_parsers')):wait(600000)" \
    +qa || warn "treesitter parser install hit an error — open nvim and run :TSUpdate"
  ok "plugins synced"
}

# ----------------------------------------------------------------------------
main() {
  printf '%s\n' "${BOLD}nvim-lazy installer${RESET}  ($OS/$ARCH)"
  [ -n "$HEADLESS" ] && info "headless server detected → skipping GUI extras (kitty, Nerd Font, clipboard tools); force GUI setup with SERVER=0"
  case "$OS" in
    Linux)  install_deps_linux ;;
    Darwin) install_deps_macos ;;
    *) die "Unsupported OS: $OS (Linux/macOS only)" ;;
  esac
  setup_config         # clone/update the repo first: install_tmux and
                        # install_kitty below copy files out of it
  install_shell        # zsh + oh-my-zsh + plugins (idempotent)
  install_tmux         # tmux + ~/.tmux.conf (only if absent)
  install_tree_sitter_cli
  install_font         # JetBrainsMono Nerd Font (icons)
  install_kitty        # kitty terminal (optional — prompts the user)
  sync_plugins
  printf '\n%s\n' "${GREEN}${BOLD}Done.${RESET} Launch with: ${BOLD}nvim${RESET}"
}

main "$@"
