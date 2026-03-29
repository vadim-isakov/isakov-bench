#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <model> <prompt> [prompt2 ...]"
  echo "       $0 <model> --all"
  echo ""
  echo "Examples:"
  echo "  $0 custom:glm-5.1 balloon"
  echo "  $0 custom:glm-5.1 balloon fish pour"
  echo "  $0 custom:glm-5.1 --all"
  exit 1
}

[[ $# -lt 2 ]] && usage

MODEL="$1"; shift
DATE=$(date +%Y%m%d)
AGENT="droid"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Extract short model name (strip "custom:" prefix if present)
MODEL_SHORT="${MODEL#custom:}"

DISABLED_TOOLS="Read,LS,Grep,Glob,Execute,Edit,FetchUrl,WebSearch,TodoWrite,Skill,Task"

# Resolve prompts
if [[ "$1" == "--all" ]]; then
  PROMPTS=()
  for f in "$SCRIPT_DIR"/prompts/*.txt; do
    PROMPTS+=("$(basename "$f" .txt)")
  done
else
  PROMPTS=("$@")
fi

for PROMPT in "${PROMPTS[@]}"; do
  PROMPT_FILE="$SCRIPT_DIR/prompts/${PROMPT}.txt"
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "ERROR: prompt file not found: $PROMPT_FILE" >&2
    exit 1
  fi

  OUT="results/${PROMPT}/${AGENT}--${MODEL_SHORT}--${DATE}.html"
  echo "==> Generating ${OUT} with ${MODEL}..."

  droid exec -m "$MODEL" --auto high \
    --disabled-tools "$DISABLED_TOOLS" \
    --output-format stream-json \
    "$(cat "$PROMPT_FILE")

Save the HTML file to: ${OUT}" \
    | jq -r '
      if .type == "tool_call" then "  > " + .toolName + " " + (.parameters.file_path // "")[:80]
      elif .type == "completion" then "  done (" + (.durationMs/1000|tostring) + "s)"
      elif .type == "message" and .role == "assistant" then "  " + .text[:120]
      else empty end'

  if [[ -f "$SCRIPT_DIR/$OUT" ]]; then
    echo "  OK: $OUT"
  else
    echo "  FAIL: $OUT not created" >&2
  fi
  echo ""
done

echo "Run ./build.sh to regenerate thumbnails and index.html"
