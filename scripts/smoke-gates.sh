#!/usr/bin/env bash
# Local-first marketplace gates (no network required for validate/heuer checks).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
ok() { echo "OK  $*"; }
bad() { echo "FAIL $*"; fail=1; }

echo "→ smoke-gates: $ROOT"

if grok plugin validate plugins/xbgst-stack >/dev/null; then
  ok "validate xbgst-stack"
else
  bad "validate xbgst-stack"
fi

if grok plugin validate plugins/grok-build-livepatch >/dev/null; then
  ok "validate grok-build-livepatch"
else
  bad "validate grok-build-livepatch"
fi

if [[ -d plugins/xbgst-stack/skills/heuer-planning ]]; then
  bad "heuer-planning must NOT ship in this marketplace"
else
  ok "heuer-planning absent"
fi

if command -v jq >/dev/null 2>&1; then
  jq empty .grok-plugin/marketplace.json
  ok "marketplace.json JSON"
elif python3 -c 'import json; json.load(open(".grok-plugin/marketplace.json"))' 2>/dev/null; then
  ok "marketplace.json JSON"
else
  bad "marketplace.json parse"
fi

if rg -n 'marketplace add VeigaPunk/grok-marketplace@' README.md >/dev/null 2>&1; then
  bad "README must not use broken marketplace add @ref form"
else
  ok "README marketplace add without @ref"
fi

if rg -n 'marketplace add .*-marketplace@' plugins/xbgst-stack/skills/xbgst-livepatch/SKILL.md >/dev/null 2>&1; then
  bad "xbgst-livepatch skill must not use broken marketplace add @ref"
else
  ok "xbgst-livepatch skill install form"
fi

if ! rg -n 'veigapunk/grok-marketplace|local/grok-marketplace' plugins/xbgst-stack/skills/xbgst-livepatch/SKILL.md >/dev/null 2>&1; then
  bad "xbgst-livepatch skill should document install pins"
else
  ok "xbgst-livepatch skill has install pins"
fi

# Nested publish must refuse
if bash plugins/xbgst-stack/livepatch/scripts/publish.sh >/dev/null 2>&1; then
  bad "nested livepatch publish.sh should refuse"
else
  code=$?
  if [[ "$code" -eq 2 ]]; then ok "nested publish.sh refuse (2)"; else bad "nested publish.sh exit $code (want 2)"; fi
fi

if bash plugins/grok-build-livepatch/scripts/publish.sh >/dev/null 2>&1; then
  bad "marketplace-nested standalone publish.sh should refuse"
else
  code=$?
  if [[ "$code" -eq 2 ]]; then ok "standalone-path publish.sh refuse under marketplace (2)"; else bad "standalone publish.sh exit $code (want 2)"; fi
fi

if [[ "$fail" -ne 0 ]]; then
  echo "→ smoke-gates FAILED"
  exit 1
fi
echo "→ smoke-gates PASSED"
