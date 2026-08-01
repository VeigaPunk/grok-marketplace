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

# install-host must not embed a default unit with REPLACE_BIN (opt-in sed under env is OK)
if rg -n 'Environment=GROK_LIVEPATCH_REPLACE_BIN=1' plugins/xbgst-stack/scripts/install-host.sh \
  | rg -v 'sed -i|GROK_LIVEPATCH_REPLACE_BIN:-|tip:|opt-in|echo ' >/dev/null 2>&1; then
  bad "install-host.sh embeds default REPLACE_BIN unit env (opt-in only)"
else
  ok "install-host REPLACE_BIN opt-in"
fi

if ! rg -n 'install-timer\.sh' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
  bad "install-host should delegate timer install to install-timer.sh"
else
  ok "install-host uses install-timer.sh"
fi

# Primary README install block must not require REPLACE_BIN on the default path
# (opt-in may appear only in comments / dedicated opt-in lines)
if awk '/^```bash$/,/^```$/' README.md | head -20 | rg -n 'GROK_LIVEPATCH_REPLACE_BIN=1' | rg -v '^\s*#' >/dev/null 2>&1; then
  # crude: fail if first code fence still has uncommented REPLACE_BIN as primary
  if sed -n '/^```bash$/,/^```$/p' README.md | head -25 | rg -n '^GROK_LIVEPATCH_FORCE=1 GROK_LIVEPATCH_REPLACE_BIN=1' >/dev/null 2>&1; then
    bad "README primary install still defaults REPLACE_BIN=1"
  else
    ok "README primary install REPLACE_BIN not required"
  fi
else
  ok "README primary install REPLACE_BIN not required"
fi

if sed -n '/After installing \*\*xbgst-stack\*\*/,/^## /p' plugins/xbgst-stack/skills/xbgst/SKILL.md \
  | rg -n '^GROK_LIVEPATCH_FORCE=1 GROK_LIVEPATCH_REPLACE_BIN=1' >/dev/null 2>&1; then
  bad "xbgst skill still defaults REPLACE_BIN=1 after install"
else
  ok "xbgst skill REPLACE_BIN opt-in"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "→ smoke-gates FAILED"
  exit 1
fi
echo "→ smoke-gates PASSED"
