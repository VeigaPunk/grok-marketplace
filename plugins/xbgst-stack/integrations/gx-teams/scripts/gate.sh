#!/usr/bin/env bash
# M01 gate: spawn echo PING-OK, title visible, capture hits, nuke, operators survive.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
S=gx-teams-toy
T="=$S"

cleanup() { "$GT" nuke --team toy >/dev/null 2>&1 || true; }
trap cleanup EXIT

# cleanup leftover toy only (exact match — never prefix-hit toybox)
if tmux has-session -t "$T" 2>/dev/null; then
  "$GT" nuke --team toy
fi

out=$("$GT" spawn --team toy --name gx-labrat-ping -- cmd echo PING-OK)
pane=$(awk '{print $2}' <<<"$out")
printf 'spawn: %s\n' "$out"

titles=$(tmux list-panes -t "$T" -F '#{pane_title} #{pane_dead}')
printf 'panes: %s\n' "$titles"
grep -q 'gx-labrat-ping' <<<"$titles"

# brief settle for echo to land
sleep 0.2
cap=$(tmux capture-pane -t "$pane" -p -S -)
printf 'capture:\n%s\n' "$cap"
grep -q 'PING-OK' <<<"$cap"

"$GT" nuke --team toy
if tmux has-session -t "$T" 2>/dev/null; then
  echo "FAIL: $S still exists after nuke" >&2
  exit 1
fi

tmux list-sessions | grep -E '^[01]:' >/dev/null
tmux has-session -t '=0'
tmux has-session -t '=1'

echo GATE_OK
