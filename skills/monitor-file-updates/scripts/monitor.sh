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
interval=${MONITOR_INTERVAL:-1}
if [[ ! $interval =~ ^[0-9]+([.][0-9]+)?$ || ! $interval =~ [1-9] ]]; then
  printf 'MONITOR_INTERVAL must be a positive number\n' >&2
  exit 1
fi
if [[ $target != /* || ! -f $target || ! -r $target ]]; then
  printf 'TARGET must be an absolute path to a readable file\n' >&2
  exit 1
fi

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

state_dir=$(mktemp -d)
trap 'rm -rf -- "$state_dir"' EXIT
trap 'exit 0' TERM INT
# GNU stat: sub-second timestamps and file identity catch rapid saves/replacement.
metadata() {
  stat -L --printf='%d:%i:%s:%y:%z' -- "$target"
}

while true; do
  observed=$(metadata)
  cp -- "$target" "$state_dir/baseline"
  [[ $(metadata) == "$observed" ]] && break
  sleep "$interval"
done
pending=0
log started "target=$target interval=${interval}s"
while true; do
  events=()
  if [[ ! -f $target || ! -r $target ]] || ! current=$(metadata 2>/dev/null); then
    log checked 'changes=0 status=unavailable'
    observed=''
    pending=0
    sleep "$interval"
    continue
  fi
  if [[ $current != "$observed" ]]; then
    if ! cp -- "$target" "$state_dir/current" 2>/dev/null ||
        ! after=$(metadata 2>/dev/null) || [[ $after != "$current" ]]; then
      log checked 'changes=0 status=unstable'
      observed=''
      pending=0
      sleep "$interval"
      continue
    fi
    observed=$current
    pending=1
  elif (( pending )); then
    pending=0
    if ! cmp -s -- "$state_dir/current" "$state_dir/baseline"; then
      diff_status=0
      difference=$(diff -u --label before --label after -- "$state_dir/baseline" "$state_dir/current") || diff_status=$?
      if (( diff_status > 1 )); then
        printf 'Cannot compare snapshots\n' >&2
        exit 1
      fi
      printf -v observation -- '- 保存後の内容変更: %s\n  前回との unified diff:\n%s' "$target" "$difference"
      events+=("$observation")
    fi
  fi
  log checked "changes=${#events[@]}"
  if (( ${#events[@]} > 0 )); then
    notify "$(printf '%s\n' "${events[@]}")" "${#events[@]}"
    cp -- "$state_dir/current" "$state_dir/baseline"
  fi
  sleep "$interval"
done
