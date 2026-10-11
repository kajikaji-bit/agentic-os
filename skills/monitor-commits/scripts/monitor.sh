#!/usr/bin/env bash
set -euo pipefail

if (( $# < 6 )); then
  printf 'Usage: %s SESSION PANE_ID NAME REPO MESSAGE PATH...\n' "$0" >&2
  exit 1
fi

session=$1
pane_id=$2
name=$3
repo=$4
message=$5
shift 5
paths=("$@" ':(exclude)workspace')
interval=${MONITOR_INTERVAL:-60}

log() {
  local event=$1
  shift
  printf '%s INFO monitor=%s event=%s %s\n' "$(date -Is)" "$name" "$event" "$*"
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
  count=$(git -C "$repo" rev-list --count "$previous..$current" -- "${paths[@]}")
  log checked "changes=$count"
  if (( count > 0 )); then
    observations=$(git -C "$repo" log --format='- %h %s' --name-only \
      "$previous..$current" -- "${paths[@]}")
    printf -v notification '[monitor:%s]\n指示: %s\n観測:\n%s' \
      "$name" "$message" "$observations"
    log detected "count=$count"
    herdr --session "$session" agent prompt "$pane_id" "$notification" >/dev/null
    log sent "pane=$pane_id"
  fi
  previous=$current
  sleep "$interval"
done
