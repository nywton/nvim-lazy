#!/usr/bin/env bash
#
# Run the headless feature tests against this config.
#
#   tests/run.sh
#
# It installs plugins to the versions pinned in lazy-lock.json (idempotent),
# then runs tests/spec.lua. Exit code is non-zero if any check fails.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

command -v nvim >/dev/null 2>&1 || { echo "nvim not found on PATH" >&2; exit 1; }

echo "==> nvim: $(nvim --version | head -n1)"
echo "==> installing/restoring plugins (lazy-lock.json)…"
nvim --headless "+Lazy! restore" +qa
# nvim-treesitter `main` branch has no :TSUpdateSync; install synchronously
# via the Lua API instead (same call scripts/install.sh and the Dockerfile use).
nvim --headless \
  "+lua require('nvim-treesitter').install(require('core.treesitter_parsers')):wait(600000)" \
  +qa 2>/dev/null || true

echo "==> running spec.lua…"
nvim --headless -c "luafile ${ROOT}/tests/spec.lua" -c "qa!"
