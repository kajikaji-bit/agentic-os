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

# {起動時の観測状態を保存する処理}
log started "target=$target interval=${interval}s"
while true; do
  events=()
  # {前回の観測と比較して events 配列へ通知する文字列を入れる処理}
  log checked "changes=${#events[@]}"
  if (( ${#events[@]} > 0 )); then
    notify "$(printf '%s\n' "${events[@]}")" "${#events[@]}"
  fi
  # {前回の観測状態を更新する処理}
  # {一度で終了する監視なら終了する処理}
  sleep "$interval"
done
