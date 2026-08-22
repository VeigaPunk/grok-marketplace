#!/usr/bin/env bash
# Identity: SKILL name is xbgst-surface, not the judge; ping is exactly xbgst armed.
set -euo pipefail

INTEG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$INTEG/SKILL.md"
PING="$INTEG/bin/xbgst-surface-ping.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$SKILL" ]] || fail "missing SKILL.md"

grep -E -q '^name: xbgst-surface$' "$SKILL" || fail "YAML name must be xbgst-surface"
if grep -E -q '^name: xbgst$' "$SKILL"; then
  fail "SKILL.md must not use name: xbgst"
fi

body="$(cat "$SKILL")"
printf '%s\n' "$body" | grep -F -q -- 'NOT' || fail "body missing NOT"
printf '%s\n' "$body" | grep -F -q -- 'judge' || fail "body missing judge"

if printf '%s\n' "$body" | grep -F -q -- 'You orchestrate, judge, and aggregate'; then
  fail "body must not contain judge orchestration phrase"
fi
if printf '%s\n' "$body" | grep -F -q -- 'spawn gx-'; then
  fail "body must not contain spawn gx-"
fi
if printf '%s\n' "$body" | grep -F -q -- '--no-subagents'; then
  fail "body must not contain --no-subagents"
fi

[[ -x "$PING" ]] || fail "ping not executable: $PING"
out="$("$PING")"
[[ "$out" == "xbgst armed" ]] || fail "ping stdout must be exactly 'xbgst armed' (got $(printf %q "$out"))"

echo "ok identity"
