#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
cleanup() { "$GT" nuke --team cap >/dev/null 2>&1 || true; }
trap cleanup EXIT
if tmux has-session -t '=gx-teams-cap' 2>/dev/null; then "$GT" nuke --team cap; fi
before0=$(tmux list-panes -s -t '=0' -F '#{pane_id}:#{pane_pid}' | sort)
before1=$(tmux list-panes -s -t '=1' -F '#{pane_id}:#{pane_pid}' | sort)
for i in $(seq 1 64); do
  "$GT" spawn --team cap --name "gx-labrat-$i" -- cmd true >/dev/null
done
n=$(tmux list-panes -s -t '=gx-teams-cap' | wc -l | tr -d ' ')
[[ "$n" == 64 ]]
dirs_before=$(find /tmp -maxdepth 1 -name 'xbgst-gx-cap-*' -type d | wc -l | tr -d ' ')
set +e
"$GT" spawn --team cap --name gx-labrat-65 -- cmd true >/tmp/gx-teams-cap65.err 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]
grep -q hardcap /tmp/gx-teams-cap65.err
dirs_after=$(find /tmp -maxdepth 1 -name 'xbgst-gx-cap-*' -type d | wc -l | tr -d ' ')
[[ "$dirs_before" == "$dirs_after" ]]
n=$(tmux list-panes -s -t '=gx-teams-cap' | wc -l | tr -d ' ')
[[ "$n" == 64 ]]
"$GT" nuke --team cap
if tmux has-session -t '=gx-teams-cap' 2>/dev/null; then echo FAIL: cap lives; exit 1; fi
[[ $(tmux list-panes -s -t '=0' -F '#{pane_id}:#{pane_pid}' | sort) == "$before0" ]]
[[ $(tmux list-panes -s -t '=1' -F '#{pane_id}:#{pane_pid}' | sort) == "$before1" ]]
echo GATE_M05_OK
