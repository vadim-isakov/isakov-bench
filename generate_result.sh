#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <model> <prompt> [prompt2 ...]"
  echo "       $0 <model> --all"
  echo "       $0 --parallel <model> <prompt> [prompt2 ...]"
  echo "       $0 --parallel <model> --all"
  echo ""
  echo "Examples:"
  echo "  $0 custom:glm-5.1 balloon"
  echo "  $0 custom:glm-5.1 balloon fish pour"
  echo "  $0 custom:glm-5.1 --all"
  echo "  $0 --parallel custom:glm-5.1 --all"
  exit 1
}

PARALLEL=false
if [[ "${1:-}" == "--parallel" ]]; then
  PARALLEL=true
  shift
fi

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

METADATA_FILE="$SCRIPT_DIR/results/metadata.json"

run_prompt() {
  local PROMPT="$1"
  local PROMPT_FILE="$SCRIPT_DIR/prompts/${PROMPT}.txt"
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "[$PROMPT] ERROR: prompt file not found: $PROMPT_FILE" >&2
    return 1
  fi

  local OUT="results/${PROMPT}/${AGENT}--${MODEL_SHORT}--${DATE}.html"
  echo "[$PROMPT] ==> Generating ${OUT} with ${MODEL}..."

  local DURATION_TMP
  DURATION_TMP=$(mktemp)

  droid exec -m "$MODEL" --auto high \
    --disabled-tools "$DISABLED_TOOLS" \
    --output-format stream-json \
    "$(cat "$PROMPT_FILE")

Save the HTML file to: ${OUT}" \
    | tee >(jq -r 'select(.type == "completion") | .durationMs' > "$DURATION_TMP") \
    | jq -r --arg p "[$PROMPT]" '
      if .type == "tool_call" then $p + "  > " + .toolName + " " + (.parameters.file_path // "")[:80]
      elif .type == "completion" then $p + "  done (" + (.durationMs/1000|tostring) + "s)"
      elif .type == "message" and .role == "assistant" then $p + "  " + .text[:120]
      else empty end'

  local DURATION_MS
  DURATION_MS=$(cat "$DURATION_TMP" 2>/dev/null || echo "")
  rm -f "$DURATION_TMP"

  if [[ -f "$SCRIPT_DIR/$OUT" ]]; then
    echo "[$PROMPT]  OK: $OUT"
    if [[ -n "$DURATION_MS" ]]; then
      echo "$OUT $DURATION_MS" >> "$SCRIPT_DIR/.duration_results.$$"
      echo "[$PROMPT]  Time: $(echo "$DURATION_MS" | jq '. / 1000')s"
    fi
  else
    echo "[$PROMPT]  FAIL: $OUT not created" >&2
  fi
}

save_metadata() {
  local DUR_FILE="$SCRIPT_DIR/.duration_results.$$"
  [[ ! -f "$DUR_FILE" ]] && return

  local METADATA
  if [[ -f "$METADATA_FILE" ]]; then
    METADATA=$(cat "$METADATA_FILE")
  else
    METADATA="{}"
  fi

  while read -r key ms; do
    METADATA=$(echo "$METADATA" | jq --arg key "$key" --argjson ms "$ms" '. + {($key): {"durationMs": $ms}}')
  done < "$DUR_FILE"

  echo "$METADATA" > "$METADATA_FILE"
  rm -f "$DUR_FILE"
  echo "Metadata saved to results/metadata.json"
}

cleanup() {
  rm -f "$SCRIPT_DIR/.duration_results.$$"
}
trap cleanup EXIT

if $PARALLEL; then
  PIDS=()
  for PROMPT in "${PROMPTS[@]}"; do
    run_prompt "$PROMPT" &
    PIDS+=($!)
  done

  FAIL=0
  for pid in "${PIDS[@]}"; do
    wait "$pid" || FAIL=1
  done

  save_metadata
  [[ $FAIL -ne 0 ]] && echo "Some prompts failed." >&2
else
  for PROMPT in "${PROMPTS[@]}"; do
    run_prompt "$PROMPT"
  done
  save_metadata
fi

echo "Run ./build.sh to regenerate thumbnails and index.html"
