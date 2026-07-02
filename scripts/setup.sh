#!/usr/bin/env bash
# setup.sh — ensure pdf2zh_next (PDFMathTranslate-next) is installed and on PATH.
# Idempotent: safe to re-run. Uses uv with Python 3.12 (the project's recommendation).
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

if command -v pdf2zh_next >/dev/null 2>&1; then
  echo "[setup] pdf2zh_next already installed: $(pdf2zh_next --version 2>/dev/null || echo 'version unknown')"
else
  echo "[setup] installing pdf2zh_next via uv (python 3.12)..."
  uv tool install --python 3.12 pdf2zh-next
fi

# Final verification.
if command -v pdf2zh_next >/dev/null 2>&1; then
  echo "[setup] OK — pdf2zh_next ready: $(command -v pdf2zh_next)"
  echo "[setup] NOTE: the first translation downloads model assets (~hundreds of MB) and will be slow."
else
  echo "ERROR: pdf2zh_next still not on PATH after install." >&2
  echo "Add $UV_BIN_DIR to your PATH and re-run, or run pdf2zh_next via 'uv tool run pdf2zh-next'." >&2
  exit 1
fi
