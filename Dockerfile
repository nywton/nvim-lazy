# syntax=docker/dockerfile:1
#
# Thin dev container: Neovim (this config) + zsh/oh-my-zsh + tmux + search tools.
#
#   docker build -t neo-nvim .
#   docker run -it --rm -v "$PWD:/work" neo-nvim        # drops you into zsh
#   docker run -it --rm -v "$PWD:/work" neo-nvim nvim   # straight into Neovim
#
# Debian-slim (glibc) is used on purpose: the prebuilt Neovim / stylua /
# tree-sitter release binaries are glibc builds and break on musl/alpine.
# Trixie (glibc 2.41) over bookworm (2.36): the prebuilt tree-sitter CLI is now
# linked against GLIBC_2.39 and won't run on bookworm.
FROM debian:trixie-slim

ARG NVIM_VERSION=stable
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

# --- system packages -------------------------------------------------------
# Build chain (treesitter parsers compile from C), search tools (ripgrep, the
# silver searcher, fd), zsh + tmux, and Python (for the black formatter).
# No nodejs/npm — this config is deliberately Node-free.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip tar locales \
      build-essential cmake ninja-build gettext pkg-config \
      ripgrep silversearcher-ag fd-find \
      zsh tmux \
      python3 python3-pip python3-venv \
    && ln -sf "$(command -v fdfind)" /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# black backs conform.nvim's python formatting.
RUN pip3 install --no-cache-dir --break-system-packages black

# --- Neovim (official release tarball, latest stable) ----------------------
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) asset="nvim-linux-x86_64.tar.gz" ;; \
      arm64) asset="nvim-linux-arm64.tar.gz" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${asset}" -o /tmp/nvim.tar.gz; \
    tar -xzf /tmp/nvim.tar.gz -C /opt; \
    mv /opt/nvim-linux-* /opt/neovim; \
    ln -sf /opt/neovim/bin/nvim /usr/local/bin/nvim; \
    rm /tmp/nvim.tar.gz; \
    nvim --version | head -n1

# --- stylua (lua formatter for conform.nvim) -------------------------------
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) sa="stylua-linux-x86_64.zip" ;; \
      arm64) sa="stylua-linux-aarch64.zip" ;; \
    esac; \
    curl -fL "https://github.com/JohnnyMorganz/StyLua/releases/latest/download/${sa}" -o /tmp/stylua.zip; \
    unzip -o /tmp/stylua.zip -d /tmp; \
    install -m 0755 /tmp/stylua /usr/local/bin/stylua; \
    rm -f /tmp/stylua.zip /tmp/stylua

# --- tree-sitter CLI -------------------------------------------------------
# REQUIRED by nvim-treesitter `main`: parsers are compiled with `tree-sitter
# build` (which then invokes the C toolchain installed above), not a bare cc.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) ta="tree-sitter-linux-x64.gz" ;; \
      arm64) ta="tree-sitter-linux-arm64.gz" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/${ta}" -o /tmp/ts.gz; \
    gunzip -f /tmp/ts.gz; \
    install -m 0755 /tmp/ts /usr/local/bin/tree-sitter; \
    rm -f /tmp/ts; \
    tree-sitter --version

# --- non-root user ---------------------------------------------------------
ARG USER=dev
ARG UID=1000
RUN useradd -m -u "${UID}" -s /usr/bin/zsh "${USER}"

# --- oh-my-zsh + plugins (autosuggestions, syntax-highlighting) ------------
USER ${USER}
ENV HOME=/home/${USER} \
    ZSH=/home/${USER}/.oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions     "${ZSH}/custom/plugins/zsh-autosuggestions" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH}/custom/plugins/zsh-syntax-highlighting"

COPY --chown=${USER}:${USER} docker/zshrc   /home/${USER}/.zshrc
COPY --chown=${USER}:${USER} docker/tmux.conf /home/${USER}/.tmux.conf

# --- the Neovim config + headless plugin install ---------------------------
COPY --chown=${USER}:${USER} . /home/${USER}/.config/nvim
# tmux status-bar stats helper (CPU/RAM/DISK/NET/Docker) — docker/tmux.conf
# above shells out to this; single source of truth is config/tmux/stats.sh,
# the same file the host installer (scripts/install.sh) deploys.
RUN mkdir -p /home/${USER}/.config/tmux \
    && cp /home/${USER}/.config/nvim/config/tmux/stats.sh /home/${USER}/.config/tmux/stats.sh \
    && chmod +x /home/${USER}/.config/tmux/stats.sh
# nvim-treesitter `main` branch: no :TSUpdateSync, and :TSUpdate is async, so
# install the configured parsers synchronously via the Lua API. The parser list
# comes from lua/config/treesitter_parsers.lua (shared with the plugin config).
RUN nvim --headless "+Lazy! restore" +qa \
    && nvim --headless \
       "+lua require('nvim-treesitter').install(require('config.treesitter_parsers')):wait(600000)" \
       +qa

# Persist shell history and nvim data across `docker run`s (see compose file).
VOLUME ["/home/dev/.local/share/nvim", "/home/dev/.zsh_history.d"]

WORKDIR /work
CMD ["zsh"]
