#!/usr/bin/env bash
set -euo pipefail

if (( $# != 5 )); then
  printf 'Usage: %s SESSION PANE_ID NAME REPO MESSAGE\n' "$0" >&2
  exit 1
fi
session=$1
pane_id=$2
name=$3
repo=$4
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

fetch() {
  git -C "$repo" fetch -q origin main || log failed 'reason=fetch'
}

fetch
previous=$(git -C "$repo" rev-parse origin/main)
log started "target=$repo interval=${interval}s"
while true; do
  fetch
  current=$(git -C "$repo" rev-parse origin/main)
  events=()
  if [[ "$current" != "$previous" ]]; then
    mapfile -t events < <(git -C "$repo" log --format='- %h %s' "$previous..$current")
  fi
  log checked "changes=${#events[@]}"
  if (( ${#events[@]} > 0 )); then
    notify "$(printf '%s\n' "${events[@]}")" "${#events[@]}"
  fi
  previous=$current
  sleep "$interval"
done
