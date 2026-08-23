#!/usr/bin/env bash
# Policy greps for /xgs native-only vs /xbgst xask-first (sekhmet/titanium/fast).
# No live model calls.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/xbgst/SKILL.md"
XBGST="$ROOT/commands/xbgst.md"
XGS="$ROOT/commands/xgs.md"
SHARED="$ROOT/commands/references/xbreed-shared.md"
SCOUT="$ROOT/agents/scout.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
need() { grep -F -q -- "$2" "$1" || fail "$1 missing '$2'"; }
forbid() {
  if grep -Eiq -- "$2" "$1"; then
    fail "$1 must not match /$2/i"
  fi
}

echo "→ test-xask-dispatch-modes: $ROOT"

# 1) xgs is native-only, not an alias of xbgst
forbid "$XGS" 'Alias for \*\*Grok `/xbgst`\*\*|Alias of /xbgst'
need "$XGS" "native-only"
need "$XGS" "mode: xgs"
if grep -F 'FIRST tool call MUST be xask --spark --gs codex' "$XGS" >/dev/null 2>&1; then
  fail "$XGS must not make spark xask mandatory"
fi

# 2) xbgst is crossbreed / xask-first
if grep -Eiq '^description:.*No xask' "$XBGST"; then
  fail "$XBGST frontmatter still says No xask"
fi
need "$XBGST" "crossbreed"
need "$XBGST" "PATH \`xask\`"
need "$XBGST" "mode: xbgst"
need "$XBGST" "service_tier=fast"
need "$XBGST" "codex-titanium"

# 3) skill distinguishes modes; old no-xask-default sentence is gone
if grep -F 'No Claude / Opus / Sonnet / xask / Codex CLI as the default path.' "$SKILL" >/dev/null 2>&1; then
  fail "$SKILL still claims no-xask as the default path"
fi
need "$SKILL" "Never spawn type \`xask\`"
need "$SKILL" "/xgs"
need "$SKILL" "/xbgst"
need "$SKILL" "mode: xbgst | xgs"

# 4) scout xask-first + 4-layer + xgs skip
need "$SCOUT" "FIRST tool"
need "$SCOUT" "xask --gs"
need "$SHARED" "--spark"
need "$SHARED" "xask --gs --service-tier fast cdx"
need "$SCOUT" "<raw_output>"
need "$SCOUT" "BLOCKED"
need "$SCOUT" "mode: xgs"
need "$SCOUT" "result.json stdout"
if grep -F 'literal substring of xask stdout' "$SCOUT" >/dev/null 2>&1; then
  fail "$SCOUT must not quote sekhmet CLI envelope as raw-quote"
fi
if grep -E 'FIRST tool call MUST be Bash: xask-l3' "$SCOUT" >/dev/null 2>&1; then
  fail "$SCOUT must not name xask-l3 as FIRST"
fi

# 5) isolation
need "$SHARED" "Never spawn type \`xask\`"
need "$SHARED" "Never use \`xask-l3\`"
need "$SHARED" "xbgst-mode"
need "$SHARED" "service_tier=fast"
need "$SHARED" "result.json"
need "$SHARED" "CollectRecord"

# 6) remaining consult roles carry xask + raw-quote; planner-class does not
for a in reviewer labrat connector executor critic sentinel mutation-tester; do
  grep -F -q 'xask --' "$ROOT/agents/$a.md" || fail "agents/$a.md missing xask lane"
  grep -F -q '<raw_output>' "$ROOT/agents/$a.md" || fail "agents/$a.md missing raw-quote"
  grep -F -q 'result.json stdout' "$ROOT/agents/$a.md" || fail "agents/$a.md missing result.json stdout extract"
done
for a in the-planner distiller scribe simplifier; do
  if grep -E 'FIRST tool call MUST be Bash: xask' "$ROOT/agents/$a.md" >/dev/null 2>&1; then
    fail "agents/$a.md gained an xask gate"
  fi
done

# 7) aliases follow xbgst-mode
for f in xb.md xbt.md xbreed.md xbreed-team.md; do
  grep -Eiq 'xbgst-mode|crossbreed|xask-first|Same as \*\*`/xbgst`\*\*' "$ROOT/commands/$f" \
    || fail "commands/$f is not xbgst-mode"
  if grep -Eiq 'optional/off unless' "$ROOT/commands/$f"; then
    fail "commands/$f still says optional/off"
  fi
done

# 8) PATH xask exists (no live consult)
command -v xask >/dev/null || fail "PATH xask missing"

echo "PASS: xask dispatch modes (M1 skeleton + scout 4-layer)"
