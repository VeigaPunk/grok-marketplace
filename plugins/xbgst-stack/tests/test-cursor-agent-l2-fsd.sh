#!/usr/bin/env bash
# Policy-only gate for hangar xbgst-cursor L2-fsd (sibling of PrimeAgent).
# Print-argv only; never XBGST_CURSOR_EXEC=1.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/xbgst/SKILL.md"
SHARED="$ROOT/commands/references/xbreed-shared.md"
ROUTING_DOC="$ROOT/docs/model-routing.md"
WRAP="$ROOT/scripts/cursor-agent-l2.sh"
CMD="$ROOT/commands/xbgst-cursor.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
need() { grep -F -q -- "$2" "$1" || fail "$1 missing '$2'"; }

need "$SKILL" "xbgst-cursor L2-fsd"
need "$SKILL" "optional OpenAI-backed PrimeAgent L2-loop"
need "$SHARED" "xbgst-cursor L2-fsd"
if grep -F 'Full-agent L2 is `xbgst-cursor-agent-surface`' "$SHARED" >/dev/null 2>&1; then
  fail "$SHARED still names surface as Full-agent L2"
fi
need "$SHARED" "trigger/forward"
need "$ROUTING_DOC" "xbgst-cursor L2-fsd"
need "$ROUTING_DOC" 'direct `prime-agent --provider openai-codex`'

[[ -x "$WRAP" ]] || fail "wrapper missing or not executable: $WRAP"
[[ -f "$CMD" ]] || fail "command missing: $CMD"

need "$CMD" "xbgst-cursor L2-fsd"
need "$CMD" "route_id"
need "$CMD" "parent"
need "$CMD" "task"
need "$CMD" "scope"
need "$CMD" "allowed_actions"
need "$CMD" "return"
need "$CMD" "stop"
need "$CMD" "Envelope documented not executed"

if grep -E 'XAI_API_KEY|PRIME_TICK_BLOCKED|/tmp/xbgst-prime-' "$WRAP" >/dev/null 2>&1; then
  fail "$WRAP must not copy prime-agent-l2 XAI/cwd guards"
fi

set +e
out="$(env -u XBGST_CURSOR_EXEC bash "$WRAP" --print ping 2>&1)"
rc=$?
set -e
[[ "$rc" -eq 0 ]] || fail "print ping rc=$rc: $out"
printf '%s\n' "$out" | grep -F -q -- 'cursor-agent' || fail "print argv missing cursor-agent: $out"
printf '%s\n' "$out" | grep -F -q -- '/xbgst-cursor' || fail "print argv missing orch workspace: $out"
if printf '%s\n' "$out" | grep -F -q -- 'xbgst-cursor-agent-surface'; then
  fail "print argv leaked surface workspace: $out"
fi
if printf '%s\n' "$out" | grep -E -q -- '--mode ask'; then
  fail "print argv must not contain --mode ask: $out"
fi
if printf '%s\n' "$out" | grep -E -q -- '--force|--yolo|--plugin-dir'; then
  fail "print argv must not contain refused flags: $out"
fi
if printf '%s\n' "$out" | grep -E -q -- 'route_id|allowed_actions'; then
  fail "wrapper must not inject envelope into argv: $out"
fi

set +e
out2="$(env -u XBGST_CURSOR_EXEC bash "$WRAP" ping 2>&1)"
rc2=$?
set -e
[[ "$rc2" -eq 0 ]] || fail "default print rc=$rc2: $out2"
printf '%s\n' "$out2" | grep -F -q -- 'cursor-agent' || fail "default print missing argv: $out2"
printf '%s\n' "$out2" | grep -F -q -- '/xbgst-cursor' || fail "default print missing orch workspace: $out2"
if printf '%s\n' "$out2" | grep -F -q -- 'xbgst-cursor-agent-surface'; then
  fail "default print leaked surface workspace: $out2"
fi

refuse() {
  local spec=$1
  set +e
  # shellcheck disable=SC2086
  o=$(env -u XBGST_CURSOR_EXEC bash "$WRAP" --print $spec 2>&1)
  r=$?
  set -e
  [[ "$r" -eq 2 ]] || fail "expected exit 2 on $spec, got $r: $o"
  grep -Eqi 'refus' <<<"$o" || fail "missing refuse text on $spec: $o"
}

refuse '--mode ask ping'
refuse '--force ping'
refuse '--yolo ping'
refuse '--plugin-dir /tmp ping'

for bin in agent Agent AGENT /usr/bin/Agent 'agent ' ' Agent'; do
  set +e
  o=$(CURSOR_AGENT_BIN="$bin" env -u XBGST_CURSOR_EXEC bash "$WRAP" --print ping 2>&1)
  r=$?
  set -e
  [[ "$r" -eq 2 ]] || fail "expected exit 2 on argv0=$bin, got $r: $o"
  grep -Eqi 'agent' <<<"$o" || fail "missing argv0=agent refuse for $bin: $o"
done

set +e
o=$(CURSOR_AGENT_BIN='   ' env -u XBGST_CURSOR_EXEC bash "$WRAP" --print ping 2>&1)
r=$?
set -e
[[ "$r" -eq 0 ]] || fail "whitespace-only CURSOR_AGENT_BIN should heal, got $r: $o"
printf '%s\n' "$o" | grep -E -q -- '^cursor-agent([[:space:]]|$)' || fail "whitespace-only BIN must print cursor-agent argv0: $o"

SUR="/home/vgpnk/Projects/xbgst/xbgst-cursor-agent-surface"
ORCH="/home/vgpnk/Projects/xbgst/xbgst-cursor"

# CWD spoof: surface tree must exit 2 with refuse text.
set +e
o=$(XBGST_CURSOR_CWD="$SUR" env -u XBGST_CURSOR_EXEC bash "$WRAP" --print ping 2>&1)
r=$?
set -e
[[ "$r" -eq 2 ]] || fail "expected exit 2 on CWD=surface spoof, got $r: $o"
grep -Eqi 'refus' <<<"$o" || fail "missing refuse text on CWD spoof: $o"

# Traversal through orch into surface must also refuse (realpath pin).
set +e
o=$(XBGST_CURSOR_CWD="$ORCH/../xbgst-cursor-agent-surface" \
  env -u XBGST_CURSOR_EXEC bash "$WRAP" --print ping 2>&1)
r=$?
set -e
[[ "$r" -eq 2 ]] || fail "expected exit 2 on CWD traversal spoof, got $r: $o"
grep -Eqi 'refus' <<<"$o" || fail "missing refuse text on CWD traversal spoof: $o"

# Explicit orch CWD still prints orch workspace.
set +e
out3="$(XBGST_CURSOR_CWD="$ORCH" env -u XBGST_CURSOR_EXEC bash "$WRAP" --print ping 2>&1)"
rc3=$?
set -e
[[ "$rc3" -eq 0 ]] || fail "explicit orch CWD rc=$rc3: $out3"
printf '%s\n' "$out3" | grep -F -q -- '/xbgst-cursor' || fail "explicit orch CWD missing orch workspace: $out3"
if printf '%s\n' "$out3" | grep -F -q -- 'xbgst-cursor-agent-surface'; then
  fail "explicit orch CWD leaked surface workspace: $out3"
fi

fake="$(mktemp /tmp/xbgst-cursor-l2-fake.XXXXXX)"
mark="$(mktemp /tmp/xbgst-cursor-l2-mark.XXXXXX)"
rm -f "$mark"
trap 'rm -f "$fake" "$mark"' EXIT
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
echo CURSOR_AGENT_RAN >>"${CURSOR_RAN_MARK:?}"
exit 99
EOF
chmod +x "$fake"
set +e
CURSOR_RAN_MARK="$mark" CURSOR_AGENT_BIN="$fake" env -u XBGST_CURSOR_EXEC \
  bash "$WRAP" --print ping >/dev/null 2>&1
set -e
[[ ! -e "$mark" ]] || fail "wrapper exec'd cursor-agent without XBGST_CURSOR_EXEC=1"

# Agent catalog pin is --model / XBGST_CURSOR_MODEL, not xask --model-id.
set +e
o=$(env -u XBGST_CURSOR_EXEC -u XBGST_CURSOR_MODEL bash "$WRAP" --print --model kimi-k3-max ping 2>&1)
r=$?
set -e
[[ "$r" -eq 0 ]] || fail "--model kimi-k3-max rc=$r: $o"
printf '%s\n' "$o" | grep -F -q -- '--model kimi-k3-max' || fail "wrap --model missing from argv: $o"
if printf '%s\n' "$o" | grep -E -q -- '--mode ask'; then
  fail "wrap --model must not add --mode ask: $o"
fi

set +e
o=$(env -u XBGST_CURSOR_EXEC bash "$WRAP" --print --model auto ping 2>&1)
r=$?
set -e
[[ "$r" -eq 2 ]] || fail "wrap --model auto should exit 2, got $r: $o"

need "$SHARED" "cursor-agent --model"
need "$ROUTING_DOC" "XBGST_CURSOR_MODEL"
need "$CMD" "--model"

echo "PASS: xbgst-cursor L2-fsd hangar row + print-only wrapper"
