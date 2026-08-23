#!/usr/bin/env bash
# M02 gate: one real grok -p in mux; PONG canary; wrapper env; operators frozen; nuke toy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
cd "$ROOT"

# leftover toy only
if tmux has-session -t '=gx-teams-toy' 2>/dev/null; then
  "$GT" nuke --team toy
fi

before0=$(tmux list-panes -s -t '=0' -F '#{pane_id}:#{pane_pid}' | sort)
before1=$(tmux list-panes -s -t '=1' -F '#{pane_id}:#{pane_pid}' | sort)
printf 'freeze0: %s\n' "$before0"
printf 'freeze1: %s\n' "$before1"

out=$("$GT" spawn --team toy --name gx-labrat-ping -- \
  cmd env GROK_SUBAGENTS=0 grok --no-leader --no-subagents --always-approve \
  -p 'Reply with exactly: GX_TEAMMATE_PONG')
printf 'spawn: %s\n' "$out"
S=$(awk '{print $1}' <<<"$out")      # gx-teams-toy
pane=$(awk '{print $2}' <<<"$out")   # %N
pid=$(awk '{print $3}' <<<"$out")    # wrapper

ok=0
for i in $(seq 1 45); do
  cap=$(tmux capture-pane -t "$pane" -p -S - 2>/dev/null || true)
  if grep -q 'GX_TEAMMATE_PONG' <<<"$cap"; then
    ok=1
    break
  fi
  sleep 2
done

if [[ $ok -ne 1 ]]; then
  printf 'capture_on_hang:\n%s\n' "$cap" >&2
  "$GT" nuke --team toy || true
  echo "Status: blocked E-auth (no GX_TEAMMATE_PONG in ${S} pane ${pane} within 90s)" >&2
  exit 2
fi

printf 'capture:\n%s\n' "$cap"
tr '\0' '\n' < /proc/"$pid"/environ | grep -qx 'GX_TEAMMATE_NAME=gx-labrat-ping'

# I-gate: grok child, not wrapper (if still live)
child=$(pgrep -P "$pid" -x grok || true)
if [[ -n "${child}" ]]; then
  [[ "$child" != "$pid" ]]
  ! ls -l /proc/"$child"/fd 2>/dev/null | grep -q leader.sock
fi
! pgrep -af claude | grep -v grep >/dev/null

"$GT" nuke --team toy
[[ $(tmux list-panes -s -t '=0' -F '#{pane_id}:#{pane_pid}' | sort) == "$before0" ]]
[[ $(tmux list-panes -s -t '=1' -F '#{pane_id}:#{pane_pid}' | sort) == "$before1" ]]

echo GATE_M02_OK
