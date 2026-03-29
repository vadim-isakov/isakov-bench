#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh
git add -A
git diff --cached --quiet && { echo "Nothing to publish."; exit 0; }
git commit -m "${1:-update}"
git push
