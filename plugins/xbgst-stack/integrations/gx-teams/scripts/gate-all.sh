#!/usr/bin/env bash
# M_final cheap gate: Godspeed + M01+M03+M04+M05+M06+mbox. Not M02 (grok -p), not M07 (ACP).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
cd "$ROOT"

TEAMS=(toy id mail cap demo mboxgate)

nuke_leftovers() {
  local t
  for t in "${TEAMS[@]}"; do
    "$GT" nuke --team "$t" >/dev/null 2>&1 || true
  done
}

assert_operators() {
  tmux has-session -t '=0' || { echo 'FAIL: operator session 0 missing' >&2; exit 1; }
  tmux has-session -t '=1' || { echo 'FAIL: operator session 1 missing' >&2; exit 1; }
  tmux list-sessions | grep -E '^[01]:' >/dev/null
}

trap nuke_leftovers EXIT

assert_operators
nuke_leftovers

bash scripts/gate-godspeed.sh
bash scripts/gate.sh
bash scripts/gate-m03.sh
bash scripts/gate-m04.sh
bash scripts/gate-m05.sh
bash scripts/gate-m06.sh
bash scripts/gate-mbox.sh

nuke_leftovers
assert_operators

echo GX-TEAMS-GATE-OK
