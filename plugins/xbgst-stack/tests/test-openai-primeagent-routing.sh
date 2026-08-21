#!/usr/bin/env bash
# Policy-only gate for optional OpenAI-backed PrimeAgent L2-loop routing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/xbgst/SKILL.md"
COMMAND="$ROOT/commands/xbgst.md"
SHARED="$ROOT/commands/references/xbreed-shared.md"
PA_SKILL="$ROOT/skills/xbgst-primeagent/SKILL.md"
PA_COMMAND="$ROOT/commands/xbgst-primeagent.md"
ROUTING_DOC="$ROOT/docs/model-routing.md"
INVENTORY="$ROOT/HOST-ORCH-INVENTORY.txt"
INSTALLER="$ROOT/scripts/install-host.sh"
MARKET_INSTALLER="$ROOT/../../scripts/install-xbgst-stack.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
need() { grep -F -q -- "$2" "$1" || fail "$1 missing '$2'"; }
forbid_ci() { if grep -Eiq -- "$2" "$1"; then fail "$1 must not match /$2/i"; fi; }

need "$SKILL" "optional OpenAI-backed PrimeAgent L2-loop"
need "$SKILL" '**L2-select** via `xbrd-selector`'
need "$SKILL" '**L3 sekhmet**'
need "$SKILL" 'route_id`, `parent`, `task`, `scope`, `allowed_actions`, `return`, and `stop`'
need "$SKILL" 'L1 alone schedules routes'
need "$SKILL" 'Keep PrimeAgent out of `HOST-ORCH-INVENTORY.txt` and the required host installer list.'

need "$COMMAND" 'attachable **L2-loop**'
need "$COMMAND" '`xbrd-selector` only as the separate L2-select lane'
need "$COMMAND" 'sekhmet only as an explicit bounded L3 escalation'
need "$SHARED" 'Substrate route table (L1 decides)'
need "$SHARED" 'Absence falls back to the named native `gx-*` path.'

need "$PA_SKILL" '`prime-agent --provider openai-codex`'
need "$PA_SKILL" 'Child fan-out is forbidden unless `allowed_actions` explicitly authorizes it.'
need "$PA_COMMAND" 'prime-agent --provider openai-codex'
need "$PA_COMMAND" '--cwd "$ROUTE_CWD"'
need "$PA_COMMAND" 'PRIME_AGENT_TELEMETRY=0 DO_NOT_TRACK=1'
need "$PA_COMMAND" 'PrimeAgent is L2-loop only, never L1 judge, L2-select, or L3.'

need "$ROUTING_DOC" 'direct `prime-agent --provider openai-codex`'
need "$ROUTING_DOC" 'legacy xAI-only compatibility path'
need "$ROUTING_DOC" 'tests/test-openai-primeagent-routing.sh'

# Window-3 host-orch surface stays PrimeAgent-free. Installer references are
# permitted only for explicit skip/exclusion, never as required overlay checks.
forbid_ci "$INVENTORY" 'prime.?agent'
need "$INSTALLER" 'xbgst-primeagent|xbgst-primeagent.md) continue'
need "$INSTALLER" 'heuer-planning|the-kimiraikkoner|xbgst-primeagent) continue'
if grep -E 'required overlay missing:.*prime.?agent' "$INSTALLER" >/dev/null 2>&1; then
  fail "$INSTALLER must not require PrimeAgent"
fi
[[ -f "$MARKET_INSTALLER" ]] || fail "missing $MARKET_INSTALLER"
forbid_ci "$MARKET_INSTALLER" 'prime.?agent'

echo "PASS: OpenAI PrimeAgent is optional L2-loop with distinct L1/L2-select/L3 boundaries"
