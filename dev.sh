#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

uv run generate.py

# Serve the site with live-reload-like workflow:
# - Watch for changes in results/, prompts/, generate.py
# - Regenerate index.html on change
# - Serve via Python's built-in HTTP server

PORT="${1:-8000}"

cleanup() {
  [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" 2>/dev/null || true
  [[ -n "${WATCH_PID:-}" ]] && kill "$WATCH_PID" 2>/dev/null || true
}
trap cleanup EXIT

uv run python -m http.server "$PORT" &
SERVER_PID=$!
echo "Serving at http://localhost:$PORT (PID $SERVER_PID)"

if command -v fswatch &>/dev/null; then
  fswatch -o results/ prompts/ generate.py | while read -r _; do
    echo "[$(date +%H:%M:%S)] Change detected, regenerating..."
    uv run generate.py
  done &
  WATCH_PID=$!
  echo "Watching for changes (fswatch PID $WATCH_PID)"
else
  echo ""
  echo "NOTE: Install fswatch for auto-rebuild on file changes:"
  echo "  brew install fswatch"
  echo ""
  echo "Without fswatch, run ./build.sh manually after changes."
  echo ""
  # Fallback: poll every 2 seconds
  (
    LAST_HASH=""
    while true; do
      HASH=$(find results prompts generate.py -type f -newer index.html 2>/dev/null | head -1)
      if [[ -n "$HASH" && "$HASH" != "$LAST_HASH" ]]; then
        LAST_HASH="$HASH"
        echo "[$(date +%H:%M:%S)] Change detected, regenerating..."
        uv run generate.py
      fi
      sleep 2
    done
  ) &
  WATCH_PID=$!
  echo "Watching for changes (polling every 2s, PID $WATCH_PID)"
fi

wait "$SERVER_PID"
