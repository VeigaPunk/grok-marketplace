#!/usr/bin/env bash
# Local-first marketplace gates (no network required for validate/heuer checks).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
ok() { echo "OK  $*"; }
bad() { echo "FAIL $*"; fail=1; }

echo "→ smoke-gates: $ROOT"

# Grok CLI plugin validate (skip on CI hosts without grok: SMOKE_SKIP_GROK=1)
if [[ "${SMOKE_SKIP_GROK:-}" == "1" ]] || ! command -v grok >/dev/null 2>&1; then
  ok "validate plugins skipped (no grok / SMOKE_SKIP_GROK=1)"
  python3 -c 'import json; json.load(open("plugins/xbgst-stack/plugin.json")); json.load(open("plugins/grok-build-livepatch/plugin.json"))' \
    && ok "plugin.json JSON" || bad "plugin.json JSON"
else
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

# install-host must not cat a custom unit; timer template owns REPLACE_BIN=1
if rg -n 'cat > .*grok-build-livepatch.service' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
  bad "install-host must not embed a custom unit (use install-timer.sh)"
else
  ok "install-host defers unit to install-timer"
fi

if ! rg -n 'install-timer\.sh' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
  bad "install-host should delegate timer install to install-timer.sh"
else
  ok "install-host uses install-timer.sh"
fi

if ! rg -n 'GROK_LIVEPATCH_ROOT="\$LP"' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
  bad "install-host should bind timer ROOT to stack livepatch via GROK_LIVEPATCH_ROOT"
else
  ok "install-host binds GROK_LIVEPATCH_ROOT to stack LP"
fi

# Unit template intentionally defaults REPLACE_BIN=1 (ban on active CLI)
if rg -n '^Environment=GROK_LIVEPATCH_REPLACE_BIN=1' plugins/xbgst-stack/livepatch/systemd/grok-build-livepatch.service >/dev/null 2>&1; then
  ok "timer unit defaults REPLACE_BIN=1 (ban active)"
else
  bad "timer unit should default REPLACE_BIN=1 for active CLI ban"
fi

if sed -n '/After installing \*\*xbgst-stack\*\*/,/^## /p' plugins/xbgst-stack/skills/xbgst/SKILL.md \
  | rg -n 'REPLACE_BIN=1' >/dev/null 2>&1; then
  ok "xbgst skill documents REPLACE_BIN default"
else
  bad "xbgst skill should document REPLACE_BIN default"
fi

if bash plugins/xbgst-stack/livepatch/scripts/gates.sh >/dev/null 2>&1; then
  ok "xbgst-stack livepatch gates.sh"
else
  bad "xbgst-stack livepatch gates.sh"
fi

if bash plugins/grok-build-livepatch/scripts/gates.sh >/dev/null 2>&1; then
  ok "standalone livepatch gates.sh"
else
  bad "standalone livepatch gates.sh"
fi

# Dual nested trees (xbgst-stack/livepatch vs plugins/grok-build-livepatch) payload match
dual_ok=1
for sub in scripts patches systemd; do
  if ! diff -rq "plugins/xbgst-stack/livepatch/$sub" "plugins/grok-build-livepatch/$sub" >/dev/null 2>&1; then
    dual_ok=0
    bad "nest vs plug DRIFT on $sub"
  fi
done
if [[ "$dual_ok" -eq 1 ]]; then
  ok "nest==plug livepatch payload"
fi

# Catalog versions lockstep with plugin.json
if python3 - <<'PY'
import json, sys
m=json.load(open(".grok-plugin/marketplace.json"))
xs=json.load(open("plugins/xbgst-stack/plugin.json"))["version"]
lp=json.load(open("plugins/grok-build-livepatch/plugin.json"))["version"]
cats={p["name"]:p["version"] for p in m["plugins"]}
assert cats.get("xbgst-stack")==xs, (cats, xs)
assert cats.get("grok-build-livepatch")==lp, (cats, lp)
assert xs==lp, (xs, lp)
print(xs)
PY
then
  ok "version lockstep catalog==plugins"
else
  bad "version lockstep catalog==plugins"
fi

if [[ -f plugins/xbgst-stack/livepatch/.standalone-tip && -f plugins/grok-build-livepatch/.standalone-tip ]]; then
  if diff -q plugins/xbgst-stack/livepatch/.standalone-tip plugins/grok-build-livepatch/.standalone-tip >/dev/null; then
    ok "standalone-tip stamps match"
  else
    bad "standalone-tip stamps differ between nest and plug"
  fi
fi

# Nested trees should match ~/Projects/grok-build-livepatch when present (scripts/patches/systemd)
if [[ -d "${STANDALONE:-$HOME/Projects/grok-build-livepatch}/scripts" ]]; then
  if bash "$ROOT/scripts/sync-livepatch-from-standalone.sh" --check >/dev/null 2>&1; then
    ok "livepatch nested trees match standalone"
  else
    bad "livepatch nested trees DRIFT (run scripts/sync-livepatch-from-standalone.sh)"
  fi
else
  ok "livepatch sync-check skipped (no standalone clone)"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "→ smoke-gates FAILED"
  exit 1
fi
echo "→ smoke-gates PASSED"
