#!/usr/bin/env bash
#
# Run the headless feature tests against this config.
#
#   tests/run.sh
#
# Runs tests/spec.lua. Exit code is non-zero if any check fails.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

command -v nvim >/dev/null 2>&1 || { echo "nvim not found on PATH" >&2; exit 1; }

echo "==> nvim: $(nvim --version | head -n1)"
echo "==> running spec.lua…"
nvim --headless -c "luafile ${ROOT}/tests/spec.lua" -c "qa!"
