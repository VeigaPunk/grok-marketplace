#!/usr/bin/env bash
# Cheap prototype gate: dry-run argv + refuse operator team 0/1. No live grok.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SH="$ROOT/scripts/xbgst-clone-l1.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$SH" ]] || fail "script not executable"

out=$(bash "$SH" --dry-run --cwd "$ROOT" -- ping-clone)
printf '%s\n' "$out" | grep -q "DRY cwd=" || fail "dry cwd"
printf '%s\n' "$out" | grep -q -- "-p /xbgst" || fail "dry prompt is /xbgst"
printf '%s\n' "$out" | grep -q "ping-clone" || fail "dry task ping-clone"
printf '%s\n' "$out" | grep -q -- "--cwd" || fail "dry grok --cwd"
printf '%s\n' "$out" | grep -q -- "--always-approve" || fail "dry always-approve"
printf '%s\n' "$out" | grep -q -- "--leader-socket" || fail "dry leader-socket"
printf '%s\n' "$out" | grep -q -- "--no-leader" && fail "grok has no --no-leader"
printf '%s\n' "$out" | grep -q "env -C" || fail "dry env -C for pane PWD"
printf '%s\n' "$out" | grep -q "gx-teams spawn --team clone" || fail "dry gx-teams spawn"
printf '%s\n' "$out" | grep -q "name=gx-l1-" || fail "dry default name gx-l1-<basename>"
printf '%s\n' "$out" | grep -q "skip_godspeed=1" || fail "dry skip gx-teams godspeed wrap on L1 -p"

if bash "$SH" --dry-run --team 0 --cwd "$ROOT" -- x 2>/dev/null; then
  fail "team 0 must refuse"
fi
if bash "$SH" --dry-run --team 1 --cwd "$ROOT" -- x 2>/dev/null; then
  fail "team 1 must refuse"
fi

out=$(bash "$SH" --dry-run --ping --cwd "$ROOT")
printf '%s\n' "$out" | grep -q "CLONE_L1_OK" || fail "ping prompt"
printf '%s\n' "$out" | grep -q -- "-p /xbgst" && fail "ping must not /xbgst"
printf '%s\n' "$out" | grep -q -- "--no-subagents" || fail "ping no-subagents"

a=$(bash "$SH" --dry-run --cwd "$ROOT" -- a)
b=$(bash "$SH" --dry-run --cwd "$ROOT" -- b)
sa=$(printf '%s\n' "$a" | sed -n 's/.*sock=\([^ ]*\).*/\1/p' | head -1)
sb=$(printf '%s\n' "$b" | sed -n 's/.*sock=\([^ ]*\).*/\1/p' | head -1)
na=$(printf '%s\n' "$a" | sed -n 's/.* name=\([^ ]*\).*/\1/p' | head -1)
nb=$(printf '%s\n' "$b" | sed -n 's/.* name=\([^ ]*\).*/\1/p' | head -1)
[[ -n "$sa" && -n "$sb" && "$sa" != "$sb" ]] || fail "two dry-runs must not share leader-socket ($sa vs $sb)"
[[ -n "$na" && -n "$nb" && "$na" != "$nb" ]] || fail "two dry-runs must not share gx-teams name ($na vs $nb)"

echo GATE_XBGST_CLONE_L1_OK
