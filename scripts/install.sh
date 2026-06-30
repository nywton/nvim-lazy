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
#   RUBY_VERSION   Ruby to install via rbenv      (default: 3.4.9)
#   RUBY_SETUP     when rvm/system Ruby exists:    (default: unset → asks)
#                  =update (rbenv) or =skip (keep existing)
#   NO_SYNC=1      skip the headless plugin sync  (default: unset → sync runs)
#   NO_RUBY=1      skip rbenv + Ruby setup        (default: unset → installs)
#   NO_SHELL=1     skip zsh/oh-my-zsh setup       (default: unset → installs)
#   NO_FONT=1      skip the Nerd Font install     (default: unset → installs)
#   NO_TMUX=1      skip tmux + ~/.tmux.conf setup (default: unset → installs)
#   NO_KITTY=1     skip kitty terminal setup      (default: unset → prompts)
#
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/nywton/nvim-lazy}"
NVIM_DIR="${NVIM_DIR:-$HOME/.config/nvim}"
# Ruby is installed via rbenv for ruby_lsp (LSP) + rubocop (formatter).
# Override the pinned version with RUBY_VERSION=..., or skip it with NO_RUBY=1.
RUBY_VERSION="${RUBY_VERSION:-3.4.9}"

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

install_deps_linux() {
  command -v apt-get >/dev/null 2>&1 || die "this script supports apt-based distros (Ubuntu/Debian). Install deps manually otherwise."
  info "Installing system packages via apt"
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -y
  # No nodejs/npm on purpose — this config is Node-free. Treesitter parsers are
  # built by the tree-sitter CLI (installed below) which invokes this C
  # toolchain; jedi-language-server installs via Mason. JS/TS/HTML/CSS are
  # formatted dependency-free via Treesitter (no biome/Node).
  # xclip / wl-clipboard back the "+/"* registers (system clipboard) so
  # :checkhealth doesn't warn "No clipboard tool found". locales lets us
  # generate a UTF-8 locale below.
  $SUDO apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip tar locales \
    build-essential cmake ninja-build gettext pkg-config \
    ripgrep fd-find \
    xclip wl-clipboard \
    fontconfig \
    python3 python3-pip python3-venv
  # Debian/Ubuntu ship fd as `fdfind`; expose the conventional `fd` name.
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    $SUDO ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi
  # Ensure a UTF-8 locale exists (Neovim's :checkhealth errors without one).
  if command -v locale-gen >/dev/null 2>&1; then
    $SUDO sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
    $SUDO locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
  fi
  install_nvim_linux
}

install_deps_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  info "Installing packages via Homebrew"
  # Node-free: no node here. jedi-language-server comes from Mason inside Neovim.
  # tree-sitter is the CLI that nvim-treesitter's `main` branch shells out to
  # when compiling parsers (`tree-sitter build`).
  # rbenv + ruby-build provide the Ruby toolchain (see install_ruby).
  brew install neovim git curl cmake ninja ripgrep fd stylua tree-sitter rbenv ruby-build || true
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
# lua/config/neovide.lua). Idempotent; skip with NO_FONT=1. Set your terminal
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
# Shell: zsh + oh-my-zsh + zsh-autosuggestions + zsh-syntax-highlighting + fzf.
# Idempotent: installs what's missing, updates what's present, and configures
# ~/.zshrc via a single guarded block (never clobbers your existing config).
# Skip entirely with NO_SHELL=1.
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

  # --- fzf (fuzzy finder) ---
  if command -v fzf >/dev/null 2>&1; then
    ok "fzf present"
  else
    info "Installing fzf"
    if [ "$OS" = "Linux" ]; then
      $SUDO apt-get install -y --no-install-recommends fzf 2>/dev/null \
        || { clone_or_update https://github.com/junegunn/fzf.git "$HOME/.fzf" \
             && "$HOME/.fzf/install" --key-bindings --completion --no-update-rc >/dev/null; }
    else
      brew install fzf || true
    fi
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

  # --- ~/.config/tmux/stats.sh — the status-bar stats helper (cpu/gpu/ram/disk)
  # referenced by status-right below. Always (re)written so updates propagate;
  # it's a generated helper, not user-editable config. No external deps.
  local stats="$HOME/.config/tmux/stats.sh"
  info "Writing $stats"
  mkdir -p "$(dirname "$stats")"
  cat > "$stats" <<'STATSSH'
#!/usr/bin/env bash
# Lightweight system stats for the tmux status bar (macOS + Linux).
# Usage: stats.sh <cpu|gpu|ram|disk>
# No external dependencies / plugins — only built-in OS tools.

os="$(uname -s)"

cpu() {
  if [ "$os" = "Darwin" ]; then
    # 100 - idle%, from a single instantaneous top sample
    top -l 1 -n 0 | awk '/CPU usage/ {
      for (i = 1; i <= NF; i++)
        if ($i == "idle") { gsub(/%/, "", $(i-1)); printf "%.1f%%", 100 - $(i-1) }
    }'
  else
    # two /proc/stat samples ~0.2s apart → instantaneous busy %
    read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
    sleep 0.2
    read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
    local idle1=$((i1 + w1)) idle2=$((i2 + w2))
    local tot1=$((u1 + n1 + s1 + i1 + w1 + q1 + sq1 + st1))
    local tot2=$((u2 + n2 + s2 + i2 + w2 + q2 + sq2 + st2))
    local dt=$((tot2 - tot1)) di=$((idle2 - idle1))
    awk -v di="$di" -v dt="$dt" 'BEGIN { printf "%.1f%%", (dt > 0 ? (1 - di / dt) * 100 : 0) }'
  fi
}

gpu() {
  if [ "$os" = "Darwin" ]; then
    # Apple Silicon GPU utilization from IOKit
    ioreg -r -d 1 -w 0 -c AGXAccelerator 2>/dev/null \
      | grep -o '"Device Utilization %"=[0-9]*' \
      | head -1 \
      | awk -F= '{ printf "%d%%", $2 }'
  elif command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null \
      | head -1 | awk '{ printf "%d%%", $1 }'
  else
    printf "n/a"
  fi
}

ram() {
  if [ "$os" = "Darwin" ]; then
    # used / total in GB (total from sysctl, used from top's PhysMem line)
    local total used
    total=$(sysctl -n hw.memsize | awk '{ printf "%.0f", $1 / 1073741824 }')
    used=$(top -l 1 -n 0 | awk '/PhysMem/ {
      v = $2
      if (v ~ /G$/)      { sub(/G/, "", v); printf "%.1f", v }
      else if (v ~ /M$/) { sub(/M/, "", v); printf "%.1f", v / 1024 }
    }')
    printf "%sGB/%sGB" "$used" "$total"
  else
    # used / total in GB from /proc/meminfo (values are in kB)
    awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 }
         END { printf "%.1fGB/%.0fGB", (t - a) / 1048576, t / 1048576 }' /proc/meminfo
  fi
}

disk() {
  # used / size of the volume that actually holds user data.
  # macOS APFS mounts a read-only *system* volume at "/" (reports almost no
  # usage); the real data lives on the Data volume. Linux just uses "/".
  local mount="/"
  [ "$os" = "Darwin" ] && mount="/System/Volumes/Data"
  df -h "$mount" | awk 'NR==2 { gsub(/Gi/, "G", $2); gsub(/Gi/, "G", $3); printf "%s/%s", $3, $2 }'
}

# Primary LAN IPv4. Named ipaddr() so it never shadows the `ip` command.
ipaddr() {
  local a=""
  if [ "$os" = "Darwin" ]; then
    a="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"
  else
    # hostname -I lists all addresses (first is the primary); fall back to the
    # route-based lookup if it's empty (e.g. hostname without the -I flag).
    a="$(hostname -I 2>/dev/null | awk '{ print $1 }')"
    [ -n "$a" ] || a="$(ip route get 1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i+1); exit } }')"
  fi
  printf '%s' "${a:-—}"
}

case "$1" in
  cpu)  cpu    ;;
  gpu)  gpu    ;;
  ram)  ram    ;;
  disk) disk   ;;
  ip)   ipaddr ;;
esac
STATSSH
  chmod +x "$stats"
  ok "stats helper → $stats"

  # --- ~/.tmux.conf ---
  # Base config: written ONLY when absent (an existing config is never
  # clobbered). The stats status bar is applied separately as a guarded
  # managed block (below) so it's added/refreshed on EVERY run — even on top
  # of a pre-existing or hand-edited config. tmux's `set -g` is last-wins, so
  # the appended block overrides any earlier status-right.
  local rc="$HOME/.tmux.conf"
  if [ -e "$rc" ]; then
    ok ".tmux.conf already exists → leaving the base config untouched"
  else
    info "Writing $rc"
    cat > "$rc" <<'TMUXCONF'
# =============================================================================
# General
# =============================================================================

set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

set -g prefix C-a
unbind C-b
bind C-a send-prefix

set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on

set -g mouse on
set -g escape-time 0
set -g history-limit 10000
set -g focus-events on

# vi mode
set-window-option -g mode-keys vi
# Use v to begin selection like Vim's visual mode
bind-key -T copy-mode-vi v send-keys -X begin-selection
# Use y to yank selection like Vim's yank
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel


# =============================================================================
# Keybinds
# =============================================================================

bind r source-file ~/.tmux.conf \; display "Config reloaded"

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# =============================================================================
# Catppuccin Mocha — matching kitty config
# =============================================================================

# Palette
# base     #1E1E2E
# mantle   #11111B (tab_bar_background in kitty)
# surface0 #313244
# overlay0 #6C7086
# text     #CDD6F4
# peach    #fab387 (active tab color in kitty)
# lavender #B4BEFE
# mauve    #CBA6F7

# Status bar
set -g status on
set -g status-position bottom
set -g status-interval 5
# "default" bg lets kitty's background_opacity bleed through
set -g status-style "bg=default,fg=#6C7086"

# Left: session name
set -g status-left " #[fg=#CBA6F7,bg=default]#{session_name}#[fg=#6C7086]  "
set -g status-left-length 30

# Windows — bg=default keeps transparency
set -g window-status-style         "bg=default"
set -g window-status-current-style "bg=default"
set -g window-status-format         "#[fg=#6C7086,bg=default] #{window_index}:#{window_name} "
set -g window-status-current-format "#[fg=#fab387,bg=default] #{window_index}:#{window_name} "
set -g window-status-separator ""

# Pane borders
set -g pane-border-style        "fg=#313244"
set -g pane-active-border-style "fg=#B4BEFE"

# Command / message line
set -g message-style "bg=#313244,fg=#CDD6F4"

# NB: the status bar's right side (system stats + IP + clock) is appended as a
# guarded managed block by the installer — keep it there so re-runs can refresh
# it. See the "# >>> nvim-lazy tmux stats >>>" block at the bottom of this file.
TMUXCONF
    ok "configured .tmux.conf"
  fi

  # --- stats status bar (guarded managed block — added/refreshed every run) ---
  # Idempotent: strip any previous block, then append the current one. tmux
  # applies `set -g` last-wins, so this overrides whatever status-right the rest
  # of the file (yours or ours) set. Remove the whole block to undo.
  info "Applying tmux stats status bar (managed block)"
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
  cat >> "$tmp" <<'TMUXSTATS'

# >>> nvim-lazy tmux stats >>>  (managed block — remove the whole block to undo)
set -g status-interval 5
set -g status-right-length 160
# system stats (cpu/gpu/ram/disk + IP via ~/.config/tmux/stats.sh) + user@host + clock
set -g status-right "#[fg=#fab387]CPU #[fg=#CDD6F4]#(~/.config/tmux/stats.sh cpu)  #[fg=#CBA6F7]GPU #[fg=#CDD6F4]#(~/.config/tmux/stats.sh gpu)  #[fg=#A6E3A1]RAM #[fg=#CDD6F4]#(~/.config/tmux/stats.sh ram)  #[fg=#89B4FA]DISK #[fg=#CDD6F4]#(~/.config/tmux/stats.sh disk)  #[fg=#F9E2AF]#(whoami)@#H #[fg=#94E2D5]#(~/.config/tmux/stats.sh ip)  #[fg=#6C7086]%H:%M  %d %b "
# <<< nvim-lazy tmux stats <<<
TMUXSTATS
  mv "$tmp" "$rc"
  ok "stats status bar applied → $rc"

  # Live-reload if we're running inside a tmux session.
  if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
    tmux source-file "$rc" >/dev/null 2>&1 && ok "reloaded running tmux config" || true
  fi
}

# ----------------------------------------------------------------------------
# Ruby (via rbenv)  —  required for ruby_lsp (LSP, installed by Mason) and
# rubocop (formatter). rbenv keeps Ruby in $HOME, no system Ruby needed.
# ----------------------------------------------------------------------------
RBENV_ROOT="${RBENV_ROOT:-$HOME/.rbenv}"

# Make the rbenv Ruby usable for the rest of THIS script run.
load_rbenv() {
  export RBENV_ROOT
  export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
  command -v rbenv >/dev/null 2>&1 && eval "$(rbenv init - bash)" 2>/dev/null || true
}

# Persist rbenv in the user's interactive shells so Neovim (and the terminals
# it spawns) can find the Ruby that backs ruby_lsp / rubocop.
persist_rbenv_to_shell() {
  local rc sh
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -e "$rc" ] || continue
    if grep -q 'rbenv init' "$rc" 2>/dev/null; then continue; fi
    case "$rc" in *zshrc) sh="zsh" ;; *) sh="bash" ;; esac
    {
      printf '\n# rbenv (added by nvim-lazy installer)\n'
      printf 'export RBENV_ROOT="$HOME/.rbenv"\n'
      printf 'export PATH="$RBENV_ROOT/bin:$PATH"\n'
      printf 'eval "$(rbenv init - %s)"\n' "$sh"
    } >> "$rc"
    ok "added rbenv init to $(basename "$rc")"
  done
}

install_ruby() {
  [ "${NO_RUBY:-}" = "1" ] && { warn "NO_RUBY=1 → skipping Ruby/rbenv setup"; return; }

  # If Ruby is already managed elsewhere — rvm, or a system/other `ruby` that
  # isn't our own rbenv shim — don't silently take it over. Ask whether to
  # update via rbenv or keep (and use) the existing install. RUBY_SETUP can
  # preset the answer for unattended runs: RUBY_SETUP=update | RUBY_SETUP=skip.
  local has_rvm="" sys_ruby="" sys_ver=""
  { command -v rvm >/dev/null 2>&1 || [ -d "$HOME/.rvm" ]; } && has_rvm=1
  if command -v ruby >/dev/null 2>&1; then
    case "$(command -v ruby)" in
      "$RBENV_ROOT"/*) : ;;   # already our rbenv Ruby — fine to manage below
      *) sys_ruby="$(command -v ruby)"; sys_ver="$(ruby -v 2>/dev/null | awk '{print $2}')" ;;
    esac
  fi

  if [ -n "$has_rvm" ] || [ -n "$sys_ruby" ]; then
    local found="" choice
    [ -n "$has_rvm" ]  && found="rvm"
    [ -n "$sys_ruby" ] && found="${found:+$found, }Ruby ${sys_ver:-?} at $sys_ruby"
    warn "Existing Ruby toolchain detected: $found"
    choice="${RUBY_SETUP:-$(prompt "Update Ruby via rbenv ([u]pdate) or skip and use the existing version ([s]kip)? [u/S] " skip)}"
    case "$choice" in
      u|U|update|Update|UPDATE) info "Updating Ruby via rbenv (per your choice)" ;;
      *) ok "Keeping existing Ruby — skipping rbenv setup"; return ;;
    esac
  fi

  if [ "$OS" = "Linux" ]; then
    # ruby-build needs these to compile Ruby (libyaml is mandatory for 3.4+).
    info "Installing Ruby build dependencies"
    $SUDO apt-get install -y --no-install-recommends \
      autoconf patch bison \
      libssl-dev libyaml-dev libreadline-dev zlib1g-dev \
      libncurses-dev libffi-dev libgdbm-dev libdb-dev uuid-dev || true
    if [ ! -d "$RBENV_ROOT" ]; then
      info "Installing rbenv + ruby-build"
      git clone --depth=1 https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
      git clone --depth=1 https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
    else
      info "Updating rbenv + ruby-build"
      git -C "$RBENV_ROOT" pull --ff-only 2>/dev/null || true
      git -C "$RBENV_ROOT/plugins/ruby-build" pull --ff-only 2>/dev/null || true
    fi
  fi
  # macOS gets rbenv + ruby-build from brew (see install_deps_macos).

  load_rbenv
  command -v rbenv >/dev/null 2>&1 || { warn "rbenv not available; skipping Ruby $RUBY_VERSION"; return; }

  if rbenv versions --bare 2>/dev/null | grep -qx "$RUBY_VERSION"; then
    ok "Ruby $RUBY_VERSION already installed"
  else
    info "Installing Ruby $RUBY_VERSION via rbenv (compiles from source — a few minutes)"
    rbenv install -s "$RUBY_VERSION" || { warn "could not build Ruby $RUBY_VERSION; 'rbenv install $RUBY_VERSION' manually"; return; }
  fi
  rbenv global "$RUBY_VERSION"
  rbenv rehash 2>/dev/null || true
  persist_rbenv_to_shell
  ok "ruby $(ruby -v 2>/dev/null | awk '{print $2}')"
}

# ----------------------------------------------------------------------------
# stylua  (lua formatter — not handled by mason here)
# ----------------------------------------------------------------------------
install_stylua() {
  command -v stylua >/dev/null 2>&1 && { ok "stylua present"; return; }
  [ "$OS" = "Darwin" ] && return   # installed via brew above

  case "$ARCH" in
    x86_64)        local sa="stylua-linux-x86_64.zip" ;;
    aarch64|arm64) local sa="stylua-linux-aarch64.zip" ;;
    *) warn "no stylua build for $ARCH; skipping"; return ;;
  esac
  info "Installing stylua ($sa)"
  local tmp; tmp="$(mktemp -d)"
  if curl -fL "https://github.com/JohnnyMorganz/StyLua/releases/latest/download/${sa}" -o "${tmp}/stylua.zip"; then
    unzip -o -q "${tmp}/stylua.zip" -d "${tmp}"
    $SUDO install -m 0755 "${tmp}/stylua" /usr/local/bin/stylua
    ok "stylua installed"
  else
    warn "could not download stylua; install it manually for lua formatting"
  fi
  rm -rf "$tmp"
}

# ----------------------------------------------------------------------------
# language formatters used by conform.nvim  (best-effort)
# ----------------------------------------------------------------------------
install_formatters() {
  install_stylua

  if command -v pip3 >/dev/null 2>&1 && ! command -v black >/dev/null 2>&1; then
    info "Installing black (python formatter)"
    pip3 install --user --quiet black 2>/dev/null \
      || pip3 install --user --quiet --break-system-packages black 2>/dev/null \
      || warn "could not install black; 'pip3 install black' manually"
  fi

  if command -v gem >/dev/null 2>&1 && ! command -v rubocop >/dev/null 2>&1; then
    info "Installing rubocop (ruby formatter)"
    gem install rubocop >/dev/null 2>&1 || warn "could not install rubocop; 'gem install rubocop' manually"
  elif ! command -v gem >/dev/null 2>&1; then
    warn "ruby/gem not found — skipping rubocop (install ruby, then 'gem install rubocop')"
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
  # same module the plugin uses (lua/config/treesitter_parsers.lua).
  info "Installing treesitter parsers (headless)…"
  nvim --headless \
    "+lua require('nvim-treesitter').install(require('config.treesitter_parsers')):wait(600000)" \
    +qa || warn "treesitter parser install hit an error — open nvim and run :TSUpdate"
  ok "plugins synced"
}

# ----------------------------------------------------------------------------
main() {
  printf '%s\n' "${BOLD}nvim-lazy installer${RESET}  ($OS/$ARCH)"
  case "$OS" in
    Linux)  install_deps_linux ;;
    Darwin) install_deps_macos ;;
    *) die "Unsupported OS: $OS (Linux/macOS only)" ;;
  esac
  install_shell        # zsh + oh-my-zsh + plugins (idempotent)
  install_tmux         # tmux + ~/.tmux.conf (only if absent)
  install_ruby         # rbenv + pinned Ruby (before formatters: rubocop needs gem)
  install_formatters
  install_tree_sitter_cli
  install_font         # JetBrainsMono Nerd Font (icons)
  install_kitty        # kitty terminal (optional — prompts the user)
  setup_config
  sync_plugins
  printf '\n%s\n' "${GREEN}${BOLD}Done.${RESET} Launch with: ${BOLD}nvim${RESET}"
}

main "$@"
