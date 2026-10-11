#!/usr/bin/env bash
set -euo pipefail

if (( $# != 5 )); then
  printf 'Usage: %s SESSION PANE_ID NAME TARGET MESSAGE\n' "$0" >&2
  exit 1
fi
session=$1
pane_id=$2
name=$3
target=$4
message=$5
interval=${MONITOR_INTERVAL:-60}

log() {
  local event=$1
  shift
  printf '%s INFO monitor=%s event=%s %s\n' "$(date -Is)" "$name" "$event" "$*"
}

notify() {
  local observations=$1 count=$2 notification
  printf -v notification '[monitor:%s]\n指示: %s\n観測:\n%s' "$name" "$message" "$observations"
  log detected "count=$count"
  herdr --session "$session" agent prompt "$pane_id" "$notification" >/dev/null
  log sent "pane=$pane_id"
}

snapshot=$(mktemp)
trap 'rm -f "$snapshot"' EXIT
declare -A previous=() current=()
scan() {
  current=()
  hunk session comment list "$target" --type user --json > "$snapshot"
  local key comment
  while IFS=$'\t' read -r key comment; do
    current["$key"]=$comment
  done < <(jq -r '.comments[]? | select(.noteId != null) | [(.noteId | tostring), (tojson)] | @tsv' "$snapshot")
}
scan
for key in "${!current[@]}"; do previous["$key"]=${current[$key]}; done
log started "target=$target interval=${interval}s"
while true; do
  scan
  events=()
  for key in "${!current[@]}"; do
    if [[ ! -v previous["$key"] ]]; then
      events+=("- sessionId=$target ${current[$key]}")
    fi
  done
  log checked "changes=${#events[@]}"
  if (( ${#events[@]} > 0 )); then
    notify "$(printf '%s\n' "${events[@]}")" "${#events[@]}"
  fi
  previous=()
  for key in "${!current[@]}"; do previous["$key"]=${current[$key]}; done
  sleep "$interval"
done
