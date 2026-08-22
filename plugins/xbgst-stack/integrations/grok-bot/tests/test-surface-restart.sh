#!/usr/bin/env bash
# Restart helper is argv0-anchored and doctor/CDP tools exist.
# Does not bounce the live app (that would kill this grok -c). Use restart.sh for live.
set -euo pipefail

INTEG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RS="$INTEG/bin/xbgst-surface-restart.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$RS" ]] || fail "restart helper missing"
grep -F -q -- "pkill -TERM -f '^/opt/Grok Bot/sand( |\$)'" "$RS" \
  || grep -F -q -- "pkill -TERM -f '^/opt/Grok Bot/sand" "$RS" \
  || fail "restart pkill is not argv0-anchored"
if grep -E "pkill -.* -f '/opt/Grok Bot/sand'" "$RS" | grep -v '\^'; then
  fail "unanchored pkill still present"
fi
[[ -x "$INTEG/bin/xbgst-surface-doctor.sh" ]] || fail "doctor missing"
command -v curl >/dev/null || fail "curl missing"
echo "ok restart-dry"
echo "pkill argv0-anchored; live bounce is bin/xbgst-surface-restart.sh"
