#!/usr/bin/env bash
# M01 ping + skill-path + host asar preflight.
set -euo pipefail

INTEG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PING="$INTEG/bin/xbgst-surface-ping.sh"
ASAR="/opt/Grok Bot/resources/app.asar"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$ASAR" ]] || fail "grok-bot asar missing: $ASAR"
[[ -x "$PING" ]] || fail "ping not executable: $PING"
[[ -f "$INTEG/SKILL.md" ]] || fail "missing $INTEG/SKILL.md"
[[ -f "$INTEG/.agents/skills/xbgst-surface/SKILL.md" ]] || fail "missing workspace SKILL.md"

if grep -E -q 'claude|xask|spawn_subagent' "$PING"; then
  fail "ping script must not mention claude/xask/spawn_subagent"
fi

out="$("$PING")"
printf '%s\n' "$out" | grep -F -q -- 'xbgst armed' || fail "ping stdout missing xbgst armed (got $(printf %q "$out"))"
[[ "$out" == "xbgst armed" ]] || fail "ping stdout must be exactly 'xbgst armed' (got $(printf %q "$out"))"

echo "ok ping"
