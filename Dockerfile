# syntax=docker/dockerfile:1
#
# Thin dev container: Neovim (this config) + zsh/oh-my-zsh + tmux + search tools.
#
#   docker build -t neo-nvim .
#   docker run -it --rm -v "$PWD:/work" neo-nvim        # drops you into zsh
#   docker run -it --rm -v "$PWD:/work" neo-nvim nvim   # straight into Neovim
#
# Debian-slim (glibc) is used on purpose: the prebuilt Neovim release binary
# is a glibc build and breaks on musl/alpine.
FROM debian:trixie-slim

ARG NVIM_VERSION=stable
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

# --- system packages -------------------------------------------------------
# Search tools (ripgrep, fzf — required by lua/finder/*.lua), zsh + tmux.
# No nodejs/npm — this config is deliberately Node-free.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip tar locales \
      ripgrep fzf \
      zsh tmux \
    && rm -rf /var/lib/apt/lists/*

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

# --- the Neovim config -------------------------------------------------
COPY --chown=${USER}:${USER} . /home/${USER}/.config/nvim
# tmux status-bar stats helper (CPU/RAM/DISK/NET/Docker) — docker/tmux.conf
# above shells out to this; single source of truth is config/tmux/stats.sh,
# the same file the host installer (scripts/install.sh) deploys.
RUN mkdir -p /home/${USER}/.config/tmux \
    && cp /home/${USER}/.config/nvim/config/tmux/stats.sh /home/${USER}/.config/tmux/stats.sh \
    && chmod +x /home/${USER}/.config/tmux/stats.sh

# Persist shell history and nvim data across `docker run`s (see compose file).
VOLUME ["/home/dev/.local/share/nvim", "/home/dev/.zsh_history.d"]

WORKDIR /work
CMD ["zsh"]
