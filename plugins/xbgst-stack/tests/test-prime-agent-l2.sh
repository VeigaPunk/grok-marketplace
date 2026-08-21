#!/usr/bin/env bash
# Fail-closed gate for L2-loop adapter (no live tick).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAP="$ROOT/scripts/prime-agent-l2.sh"
SKILL="$ROOT/skills/xbgst-primeagent/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$WRAP" ]] || fail "wrapper missing or not executable: $WRAP"
[[ -f "$SKILL" ]] || fail "skill missing: $SKILL"

for needle in BANNED general-purpose explore; do
  grep -q -- "$needle" "$WRAP" || fail "wrapper missing '$needle'"
  grep -q -- "$needle" "$SKILL" || fail "skill missing '$needle'"
done

# Basename must be exactly prime-agent (never OR-in host pi).
grep -q 'basename "${PRIME_AGENT_BIN}")" != "prime-agent"' "$WRAP" || fail "wrapper missing exact basename prime-agent guard"
if grep 'basename "${PRIME_AGENT_BIN}"' "$WRAP" | grep -q '"pi"'; then
  fail "basename check must not accept pi"
fi

set +e
out="$(env -u XAI_API_KEY bash "$WRAP" -p 'noop' 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || fail "expected exit 2 without XAI_API_KEY, got $rc"
echo "$out" | grep -q 'PRIME_TICK_BLOCKED_NO_XAI' || fail "missing PRIME_TICK_BLOCKED_NO_XAI in output: $out"

set +e
out2="$(cd "$ROOT" && env XAI_API_KEY=xbgst-reviewer-dummy bash "$WRAP" -p 'noop' 2>&1)"
rc2=$?
set -e
[[ "$rc2" -eq 2 ]] || fail "expected exit 2 on non-disposable cwd, got $rc2"
echo "$out2" | grep -q 'PRIME_TICK_BLOCKED_CWD' || fail "missing PRIME_TICK_BLOCKED_CWD in output: $out2"

tmpcwd="$(mktemp -d /tmp/xbgst-prime-sentinel.XXXXXX)"
set +e
out3="$(cd "$tmpcwd" && env XAI_API_KEY=xbgst-sentinel-dummy bash "$WRAP" /login 2>&1)"
rc3=$?
out4="$(cd "$tmpcwd" && env XAI_API_KEY=xbgst-sentinel-dummy bash "$WRAP" --provider anthropic 2>&1)"
rc4=$?
out5="$(cd "$tmpcwd" && env XAI_API_KEY=xbgst-sentinel-dummy bash "$WRAP" -p general-purpose 2>&1)"
rc5=$?
out6="$(cd "$tmpcwd" && env XAI_API_KEY=xbgst-sentinel-dummy bash "$WRAP" -p explore 2>&1)"
rc6=$?
set -e
rmdir "$tmpcwd" 2>/dev/null || true
[[ "$rc3" -eq 2 ]] || fail "expected exit 2 on /login argv, got $rc3"
echo "$out3" | grep -q 'PRIME_TICK_BLOCKED_LOGIN' || fail "missing PRIME_TICK_BLOCKED_LOGIN in output: $out3"
[[ "$rc4" -eq 2 ]] || fail "expected exit 2 on --provider anthropic, got $rc4"
echo "$out4" | grep -q 'PRIME_TICK_BLOCKED_PROVIDER' || fail "missing PRIME_TICK_BLOCKED_PROVIDER in output: $out4"
[[ "$rc5" -eq 2 ]] || fail "expected exit 2 on general-purpose argv, got $rc5"
echo "$out5" | grep -q 'PRIME_TICK_BLOCKED_BANNED_TYPE' || fail "missing PRIME_TICK_BLOCKED_BANNED_TYPE in output: $out5"
[[ "$rc6" -eq 2 ]] || fail "expected exit 2 on explore argv, got $rc6"
echo "$out6" | grep -q 'PRIME_TICK_BLOCKED_BANNED_TYPE' || fail "missing PRIME_TICK_BLOCKED_BANNED_TYPE on explore: $out6"

echo "PASS: prime-agent-l2 fail-closed + ban strings"
