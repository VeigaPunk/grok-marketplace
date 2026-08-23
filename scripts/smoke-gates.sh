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
if ! rg -n 'install-timer\.sh.*\$\{GROK_LIVEPATCH_ROOT\}/scripts/install-timer\.sh|--install-timer|--rebind-timer' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
  bad "install-host should expose explicit --install-timer/--rebind-timer"
else
  ok "install-host timer wiring is explicit opt-in"
fi

if ! rg -n 'GROK_LIVEPATCH_ROOT="\$LP"' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
  bad "install-host should bind timer ROOT to stack livepatch via GROK_LIVEPATCH_ROOT"
else
  ok "install-host binds GROK_LIVEPATCH_ROOT to stack LP"
fi

# Prevent regression to Projects-canonical preference (marketplace-first policy)
if rg -n 'prefer canonical Projects|FORCE_STACK_LP|CANON=.*grok-build-livepatch' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
  bad "install-host must not prefer Projects/grok-build-livepatch over stack LP"
else
  ok "install-host marketplace-first (no Projects CANON preference)"
fi

if [[ -f plugins/xbgst-stack/integrations/gx-teams/gx-teams.sh && -f plugins/xbgst-stack/integrations/gx-teams/mailbox/Cargo.toml ]]; then
  ok "gx-teams mailbox vendored under integrations/"
else
  bad "gx-teams mailbox missing from xbgst-stack/integrations/gx-teams"
fi

if rg -n 'command -v fnm' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1 \
  && rg -n 'BLOCKED: fnm missing|fnm missing' plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
  ok "install-host fail-closes without fnm"
else
  bad "install-host must fail-closed if fnm is missing"
fi

SKILL=plugins/xbgst-stack/skills/xbgst/SKILL.md
if python3 - <<'PY'
from pathlib import Path
p=Path("plugins/xbgst-stack/skills/xbgst/SKILL.md").read_text()
assert "fnm" in p.lower()
for needle in ["If fnm unavailable, fall back", "Fallback pure bash isolation", "pure-bash-isolated"]:
    if needle in p:
        raise SystemExit(f"FAIL leftover default: {needle}")
assert "spawn_method: fnm-multishell" in p
sp=p.split("## Spawn protocol")[1].split("## WWKD")[0] if "## Spawn protocol" in p else ""
assert "env -i" not in sp
print("FNM_ALWAYS_OK")
PY
then
  ok "xbgst SKILL fnm-always (no env -i spawn default)"
else
  bad "xbgst SKILL still documents env -i spawn fallback"
fi

if python3 - <<'PY'
from pathlib import Path
p=Path("SURFACES.md").read_text()
assert "grok-titanium" in p
assert "HOST.md name; **PATH-MISS**" not in p
print("SURFACES_TITANIUM_OK")
PY
then
  ok "SURFACES grok-titanium is not PATH-MISS"
else
  bad "SURFACES still claims grok-titanium PATH-MISS"
fi

if [[ -f scripts/overlays/install-host.xbgst-stack.sh ]]; then
  if diff -q scripts/overlays/install-host.xbgst-stack.sh plugins/xbgst-stack/scripts/install-host.sh >/dev/null 2>&1; then
    ok "install-host matches marketplace overlay"
  else
    bad "install-host drifts from scripts/overlays/install-host.xbgst-stack.sh"
  fi
  if ! rg -n 'install-host\.xbgst-stack\.sh|--install-timer|--rebind-timer|--no-timer' scripts/overlays/install-host.xbgst-stack.sh >/dev/null 2>&1; then
    bad "overlay install-host should expose timer opt-in"
  else
    ok "overlay install-host exposes timer opt-in"
  fi
fi

# Exercise host-install argument behavior with a fake timer: default and
# compatibility --no-timer must not call it; explicit opt-in must call it.
timer_probe=$(mktemp -d)
mkdir -p "$timer_probe/stack/scripts" "$timer_probe/stack/livepatch/scripts"
cp plugins/xbgst-stack/scripts/install-host.sh "$timer_probe/stack/scripts/install-host.sh"
cat >"$timer_probe/stack/livepatch/scripts/install-timer.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TIMER_MARKER"
EOF
chmod +x "$timer_probe/stack/livepatch/scripts/install-timer.sh"
if TIMER_MARKER="$timer_probe/calls" HOME="$timer_probe/home" GROK_HOME="$timer_probe/grok" \
    bash "$timer_probe/stack/scripts/install-host.sh" >/dev/null \
    && [[ ! -e "$timer_probe/calls" ]] \
    && TIMER_MARKER="$timer_probe/calls" HOME="$timer_probe/home" GROK_HOME="$timer_probe/grok" \
      bash "$timer_probe/stack/scripts/install-host.sh" --no-timer >/dev/null \
    && [[ ! -e "$timer_probe/calls" ]]; then
  ok "install-host default and --no-timer leave timer untouched"
else
  bad "install-host changed timer without explicit opt-in"
fi
if TIMER_MARKER="$timer_probe/calls" HOME="$timer_probe/home" GROK_HOME="$timer_probe/grok" \
    bash "$timer_probe/stack/scripts/install-host.sh" --install-timer >/dev/null \
    && [[ -s "$timer_probe/calls" ]]; then
  ok "install-host --install-timer invokes optional timer installer"
else
  bad "install-host --install-timer did not invoke timer installer"
fi
rm -rf "$timer_probe"

if rg -n -- '--install-timer|--rebind-timer|--no-timer' scripts/overlays/sync-stack-livepatch.marketplace-safe.sh >/dev/null 2>&1 \
  && rg -n -- '--install-timer|--rebind-timer|--no-timer' scripts/sync-livepatch-from-standalone.sh >/dev/null 2>&1; then
  ok "sync scripts expose explicit timer opt-in"
else
  bad "sync scripts missing explicit timer opt-in"
fi

if rg -n 'INSTALL_TIMER=0' scripts/sync-livepatch-from-standalone.sh scripts/overlays/sync-stack-livepatch.marketplace-safe.sh >/dev/null 2>&1 \
  && rg -n 'if \[\[ "\$INSTALL_TIMER" -eq 1 \]\]' scripts/sync-livepatch-from-standalone.sh scripts/overlays/sync-stack-livepatch.marketplace-safe.sh >/dev/null 2>&1 \
  && rg -n -- '--no-timer\) : ;;' scripts/sync-livepatch-from-standalone.sh scripts/overlays/sync-stack-livepatch.marketplace-safe.sh >/dev/null 2>&1; then
  ok "sync timer changes are opt-in; --no-timer is a compatibility no-op"
else
  bad "sync timer defaults or --no-timer compatibility behavior regressed"
fi

# Reproduce the installed-plugin layout. The script's only sync target would be
# its own livepatch root, so it must no-op rather than cp a file onto itself.
sync_probe=$(mktemp -d)
sync_lp="$sync_probe/home/.grok/installed-plugins/xbgst-stack-1.2.3/livepatch"
mkdir -p "$sync_lp/scripts" "$sync_lp/systemd" "$sync_lp/patches"
cp scripts/overlays/sync-stack-livepatch.marketplace-safe.sh \
  "$sync_lp/scripts/sync-stack-livepatch.sh"
cat >"$sync_lp/scripts/install-timer.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TIMER_MARKER"
exit "${TIMER_EXIT:-0}"
EOF
chmod +x "$sync_lp/scripts/"*.sh
sync_before=$(sha256sum "$sync_lp/scripts/sync-stack-livepatch.sh")
if TIMER_MARKER="$sync_probe/timer-calls" \
    bash "$sync_lp/scripts/sync-stack-livepatch.sh" >"$sync_probe/default.out" \
    && [[ ! -e "$sync_probe/timer-calls" ]] \
    && rg -n 'skip sync self-copy:' "$sync_probe/default.out" >/dev/null \
    && [[ "$sync_before" == "$(sha256sum "$sync_lp/scripts/sync-stack-livepatch.sh")" ]]; then
  ok "versioned installed-plugin sync exits zero without self-copy"
else
  bad "versioned installed-plugin sync self-copy regression"
fi
if TIMER_MARKER="$sync_probe/timer-calls" \
    bash "$sync_lp/scripts/sync-stack-livepatch.sh" --no-timer >/dev/null \
    && [[ ! -e "$sync_probe/timer-calls" ]]; then
  ok "installed-plugin --no-timer remains a compatibility no-op"
else
  bad "installed-plugin --no-timer changed timer state"
fi
if TIMER_MARKER="$sync_probe/timer-calls" \
    bash "$sync_lp/scripts/sync-stack-livepatch.sh" --install-timer >/dev/null \
    && [[ -s "$sync_probe/timer-calls" ]]; then
  ok "installed-plugin timer remains explicit opt-in"
else
  bad "installed-plugin --install-timer did not invoke timer installer"
fi
set +e
TIMER_MARKER="$sync_probe/timer-calls" TIMER_EXIT=42 \
  bash "$sync_lp/scripts/sync-stack-livepatch.sh" --install-timer >/dev/null
timer_failure_code=$?
set -e
if [[ "$timer_failure_code" -eq 42 ]]; then
  ok "installed-plugin timer installer failure propagates exit 42"
else
  bad "installed-plugin timer installer failure was suppressed (exit $timer_failure_code)"
fi
rm -rf "$sync_probe"

if cmp -s scripts/overlays/sync-stack-livepatch.marketplace-safe.sh \
    plugins/xbgst-stack/livepatch/scripts/sync-stack-livepatch.sh \
  && cmp -s scripts/overlays/sync-stack-livepatch.marketplace-safe.sh \
    plugins/grok-build-livepatch/scripts/sync-stack-livepatch.sh; then
  ok "marketplace-safe sync overlay matches both vendored copies"
else
  bad "marketplace-safe sync overlay drifts from vendored copies"
fi

if rg -n 'cron: "0 \*/6 \* \* \*"' .github/workflows/livepatch-watch.yml >/dev/null 2>&1; then
  ok "GitHub livepatch watch remains on six-hour schedule"
else
  bad "GitHub livepatch watch six-hour schedule changed"
fi

if [[ -f plugins/xbgst-stack/livepatch/scripts/sync-stack-livepatch.sh ]] \
  && rg -n 'prefer canonical Projects livepatch|Managed/synced by grok-build-livepatch' \
    plugins/xbgst-stack/livepatch/scripts/sync-stack-livepatch.sh >/dev/null 2>&1; then
  bad "nested sync-stack-livepatch.sh still rewrites install-host (need marketplace-safe overlay)"
else
  ok "nested sync-stack-livepatch is marketplace-safe"
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

# Full gates on stack nest (preferred marketplace timer ROOT when host unit exists).
if bash plugins/xbgst-stack/livepatch/scripts/gates.sh >/dev/null 2>&1; then
  ok "xbgst-stack livepatch gates.sh"
else
  bad "xbgst-stack livepatch gates.sh (try ./scripts/rebind-livepatch-timer.sh)"
fi

# Twin tree shares one user unit — only one ROOT can match ExecStart.
# On CI (no unit) both full gates pass; on host with unit→nest, only offline subset for plug.
UNIT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/grok-build-livepatch.service"
if [[ ! -f "$UNIT_FILE" ]] || grep -q 'plugins/grok-build-livepatch' "$UNIT_FILE" 2>/dev/null; then
  if bash plugins/grok-build-livepatch/scripts/gates.sh >/dev/null 2>&1; then
    ok "plugin livepatch gates.sh"
  else
    bad "plugin livepatch gates.sh"
  fi
else
  plug_bn=0
  for s in plugins/grok-build-livepatch/scripts/*.sh; do
    bash -n "$s" || plug_bn=1
  done
  if [[ "$plug_bn" -eq 0 ]]; then
    ok "plugin livepatch bash -n (full gates skipped: unit bound to nest)"
  else
    bad "plugin livepatch bash -n"
  fi
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
STAND="${STANDALONE:-$HOME/Projects/grok-build-livepatch}"
if [[ -d "$STAND/scripts" ]]; then
  if bash "$ROOT/scripts/sync-livepatch-from-standalone.sh" --check >/dev/null 2>&1; then
    ok "livepatch nested trees match standalone"
  else
    bad "livepatch nested trees DRIFT (run scripts/sync-livepatch-from-standalone.sh)"
  fi
  if [[ -f plugins/xbgst-stack/livepatch/.standalone-tip ]] && command -v git >/dev/null 2>&1; then
    tip=$(tr -d '[:space:]' <plugins/xbgst-stack/livepatch/.standalone-tip)
    head=$(git -C "$STAND" rev-parse --short HEAD 2>/dev/null || true)
    if [[ -n "$head" && "$tip" != "$head" ]]; then
      bad "standalone-tip stamp $tip ≠ standalone HEAD $head (re-run sync)"
    else
      ok "standalone-tip stamp == standalone HEAD ($tip)"
    fi
  fi
else
  ok "livepatch sync-check skipped (no standalone clone)"
fi

# orch-parity (M07): grok plugin install skips skill symlinks.
if [[ -d plugins/xbgst-stack/skills/godspeed && -d plugins/xbgst-stack/skills/wwkd ]]; then
  ok "skills godspeed+wwkd present"
else
  bad "skills godspeed/wwkd missing"
fi
orch_reg_ok=1
for f in \
  plugins/xbgst-stack/skills/godspeed/SKILL.md \
  plugins/xbgst-stack/skills/godspeed/directive.md \
  plugins/xbgst-stack/skills/wwkd/SKILL.md \
  plugins/xbgst-stack/ssot/godspeed-core/directive.md \
  plugins/xbgst-stack/ssot/godspeed-core/filter.md \
  plugins/xbgst-stack/ssot/godspeed-core/velocity.md
do
  if [[ -L "$f" ]]; then
    bad "$f is a symlink (grok install skips symlinks)"
    orch_reg_ok=0
  elif [[ ! -f "$f" ]]; then
    bad "$f missing (want regular file)"
    orch_reg_ok=0
  fi
done
if [[ "$orch_reg_ok" -eq 1 ]]; then
  ok "orch ssot/skills regular files (godspeed/directive.md not a symlink)"
fi
if cmp -s plugins/xbgst-stack/skills/godspeed/directive.md \
        plugins/xbgst-stack/ssot/godspeed-core/directive.md; then
  ok "godspeed/directive.md matches ssot copy"
else
  bad "godspeed/directive.md drifts from ssot/godspeed-core/directive.md"
fi

janitor_skill=plugins/xbgst-stack/skills/the-janitor/SKILL.md
if rg -F '../../ssot/godspeed-core/directive.md' "$janitor_skill" >/dev/null \
  && rg -F 'append exactly one final `| godspeed`' "$janitor_skill" >/dev/null \
  && rg -F 'Apply the same construction to every follow-up or resume.' "$janitor_skill" >/dev/null \
  && ! rg -F 'prompt="<task:' "$janitor_skill" >/dev/null; then
  ok "the-janitor dispatch uses canonical Godspeed + exactly-once suffix"
else
  bad "the-janitor dispatch drifts from canonical Godspeed contract"
fi

kim_extra=$(rg -n 'the-kimiraikkoner' plugins/xbgst-stack | rg -v 'HOST-ORCH-INVENTORY\.txt' | rg -v 'continue' | rg -v 'the-bootstrapper' | rg -v 'test-bootstrapper' || true)
if [[ -n "$kim_extra" ]]; then
  bad "the-kimiraikkoner under plugins/xbgst-stack (only inventory [banned] or skip-lists allowed)"
else
  ok "the-kimiraikkoner only in inventory/skip-lists"
fi

if rg -n 'vgpnk1337' plugins/xbgst-stack >/dev/null 2>&1; then
  bad "vgpnk1337 must not appear under plugins/xbgst-stack"
else
  ok "no vgpnk1337 under xbgst-stack"
fi

inv=plugins/xbgst-stack/HOST-ORCH-INVENTORY.txt
if [[ -f "$inv" ]] && rg -n '^godspeed$' "$inv" >/dev/null && rg -n '^wwkd$' "$inv" >/dev/null; then
  ok "HOST-ORCH-INVENTORY names wwkd godspeed"
else
  bad "HOST-ORCH-INVENTORY missing or does not name wwkd godspeed"
fi

if { [[ -f plugins/xbgst-stack/hooks/hooks.json ]] && rg -n 'install-host\.sh' plugins/xbgst-stack/hooks/hooks.json >/dev/null 2>&1; } \
  || { [[ -f hooks/hooks.json ]] && rg -n 'install-host\.sh' hooks/hooks.json >/dev/null 2>&1; }; then
  bad "hooks.json must not exec install-host.sh"
else
  ok "no hooks.json exec of install-host.sh"
fi

if [[ -f scripts/sync-orch-ssot.sh && -d "${HOME}/Projects/xbgst/myskills" ]]; then
  if bash scripts/sync-orch-ssot.sh --check >/dev/null 2>&1; then
    ok "sync-orch-ssot --check"
  else
    bad "sync-orch-ssot --check (orch ssot/skills drift)"
  fi
fi

# Prefer requiring the oneliner; WARN (not FAIL) if still racing into existence.
if [[ -f scripts/install-xbgst-stack.sh ]]; then
  ok "install-xbgst-stack.sh present"
else
  echo "WARN install-xbgst-stack.sh missing (oneliner race)"
fi

# xask-first contract (no live model). Extract-aware; XASK_LIVE=0.
if bash plugins/xbgst-stack/tests/test-xask-dispatch-modes.sh; then
  ok "xask dispatch modes"
else
  bad "xask dispatch modes"
fi
if XASK_LIVE=0 bash plugins/xbgst-stack/tests/test-xask-midrun-ping.sh; then
  ok "xask midrun ping fixtures"
else
  bad "xask midrun ping fixtures"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "→ smoke-gates FAILED"
  exit 1
fi
echo "→ smoke-gates PASSED"
