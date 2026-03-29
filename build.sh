#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Generating video thumbnails..."
uv run --group dev generate_thumbnails.py

echo "==> Generating index.html..."
uv run --group dev generate.py
