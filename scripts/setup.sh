#!/usr/bin/env bash
# setup.sh — ensure pdf2zh_next (PDFMathTranslate-next) is installed and on PATH.
#
# Idempotent and FAST on subsequent runs: if pdf2zh_next is already installed
# and the model assets are already cached, this returns near-instantly and
# silently (it does NOT spawn a Python import or call `--version`, which would
# re-emit engine-selection warnings every time). Re-running is always safe.
set -euo pipefail

# Ensure uv's tool bin dir is on PATH for this shell and any child process.
UV_BIN_DIR="$HOME/.local/bin"
case ":$PATH:" in
  *":$UV_BIN_DIR:"*) ;;
  *) export PATH="$UV_BIN_DIR:$PATH" ;;
esac

command -v uv >/dev/null 2>&1 || {
  echo "ERROR: 'uv' is not installed. Install it first:" >&2
  echo "  curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
}

# Model assets (DocLayout-YOLO + fonts) are downloaded by pdf2zh_next/babeldoc
# on the first real translation and cached here afterwards.
BABELDOC_CACHE="$HOME/.cache/babeldoc"
models_cached() {
  [[ -d "$BABELDOC_CACHE/models" ]] && [[ -n "$(ls -A "$BABELDOC_CACHE/models" 2>/dev/null)" ]]
}

# --- fast path: already installed (no Python import, no warning spew) ---
if command -v pdf2zh_next >/dev/null 2>&1; then
  if models_cached; then
    echo "[setup] ready — pdf2zh_next installed and models cached. Nothing to do; safe to skip on future runs."
  else
    echo "[setup] ready — pdf2zh_next installed at $(command -v pdf2zh_next)."
    echo "[setup] NOTE: first translation will download model assets (~hundreds of MB, one-time)."
  fi
  exit 0
fi

# --- install path ---
echo "[setup] installing pdf2zh_next via uv (python 3.12)..."
uv tool install --python 3.12 pdf2zh-next

if command -v pdf2zh_next >/dev/null 2>&1; then
  echo "[setup] installed — $(command -v pdf2zh_next)"
  echo "[setup] NOTE: first translation will download model assets (~hundreds of MB, one-time)."
else
  echo "ERROR: pdf2zh_next still not on PATH after install." >&2
  echo "Add $UV_BIN_DIR to your PATH and re-run, or run pdf2zh_next via 'uv tool run pdf2zh-next'." >&2
  exit 1
fi
