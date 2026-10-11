#!/usr/bin/env bash
set -euo pipefail

if (( $# < 5 || $# > 7 )); then
  printf 'Usage: %s SESSION PANE_ID NAME DATE_EXPRESSION MESSAGE [REPEAT_SECONDS] [all|weekdays]\n' "$0" >&2
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

repeat=${6:-0}
days=${7:-all}
target_at=$(date -d "$target" +%s)
now=$(date +%s)
if (( repeat > 0 )); then
  while (( target_at <= now )); do target_at=$((target_at + repeat)); done
elif (( target_at <= now )); then
  printf '指定された時刻は既に過ぎている\n' >&2
  exit 1
fi
log started "target=$target interval=${interval}s"
while true; do
  now=$(date +%s)
  count=0
  if (( now >= target_at )); then
    if [[ "$days" != weekdays ]] || (( $(date -d "@$target_at" +%u) <= 5 )); then
      count=1
    fi
    log checked "changes=$count"
    if (( count > 0 )); then notify "- $(date -d "@$target_at" -Is)" 1; fi
    if (( repeat == 0 )); then break; fi
    while (( target_at <= now )); do target_at=$((target_at + repeat)); done
  else
    log checked 'changes=0'
  fi
  delay=$((target_at - $(date +%s)))
  if (( delay > interval )); then delay=$interval; fi
  if (( delay > 0 )); then sleep "$delay"; fi
done
