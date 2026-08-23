#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
STATE="${GX_TEAMS_STATE:-$HOME/.gx-teams}"
cleanup() { "$GT" nuke --team demo >/dev/null 2>&1 || true; }
trap cleanup EXIT
if tmux has-session -t '=gx-teams-demo' 2>/dev/null; then "$GT" nuke --team demo; fi
"$GT" spawn --team demo --name gx-scout-docs -- cmd true
"$GT" spawn --team demo --name gx-labrat-ping -- cmd true
titles=$(tmux list-panes -s -t '=gx-teams-demo' -F '#{pane_title}' | sort)
printf 'titles:\n%s\n' "$titles"
grep -qx gx-scout-docs <<<"$titles"
grep -qx gx-labrat-ping <<<"$titles"
"$GT" dm --team demo --to gx-scout-docs --text hi-scout | grep -q sent
"$GT" dm --team demo --to gx-labrat-ping --text hi-labrat | grep -q sent
tail -n 1 "$STATE/demo/inboxes/gx-scout-docs.jsonl" | jq -e '.text=="hi-scout"'
tail -n 1 "$STATE/demo/inboxes/gx-labrat-ping.jsonl" | jq -e '.text=="hi-labrat"'
for n in gx-scout-docs gx-labrat-ping; do
  f="$STATE/demo/godspeed/$n.txt"
  test -f "$f"
  grep -F 'Name the axes' "$f"
  grep -F 'Iterate cheap, in parallel' "$f"
  grep -F 'Keep moves that improve any axis and harm none' "$f"
  grep -F "Don't aim" "$f"
done
! grep -q TeamCreate "$GT"
"$GT" nuke --team demo
echo GATE_M06_OK
