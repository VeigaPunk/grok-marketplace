#!/usr/bin/env bash
# M03 installer: dest symlink → this integration; rerun ok; settings.json untouched.
# Uses a temp dest — never the live $HOME/.agents/skills/xbgst-surface.
set -euo pipefail

INTEG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$INTEG/install-grok-bot-surface.sh"
TMP="$(mktemp -d)"
DEST="$TMP/xbgst-surface"
WF="$TMP/workflows/xbgst-surface"
FLAGS="$TMP/grok-bot-flags.conf"
SETTINGS="$HOME/.grokbot/settings.json"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$INSTALL" ]] || fail "missing installer: $INSTALL"

want=$(readlink -f "$INTEG")
before=""
had_settings=0
if [[ -f "$SETTINGS" ]]; then
  had_settings=1
  before=$(sha256sum "$SETTINGS")
fi

run_install() {
  XBGST_SURFACE_DEST="$DEST" \
    XBGST_SURFACE_WORKFLOW="$WF" \
    XBGST_SURFACE_FLAGS="$FLAGS" \
    bash "$INSTALL"
}

run_install || fail "installer first run"
[[ -L "$DEST" ]] || fail "dest is not a symlink: $DEST"
got=$(readlink -f "$DEST")
[[ "$got" == "$want" ]] || fail "dest target $got != integration $want"
[[ -L "$WF/SKILL.md" ]] || fail "workflow SKILL.md not a symlink"
grep -F -q -- '--remote-debugging-port=9333' "$FLAGS" || fail "flags missing CDP port: $(cat "$FLAGS")"

run_install || fail "installer rerun"
got=$(readlink -f "$DEST")
[[ "$got" == "$want" ]] || fail "rerun dest target $got != integration $want"
grep -F -q -- '# xbgst-surface begin' "$FLAGS" || fail "flags missing managed block"

if [[ "$had_settings" -eq 1 ]]; then
  after=$(sha256sum "$SETTINGS")
  [[ "$before" == "$after" ]] || fail "settings.json checksum changed"
else
  [[ ! -e "$SETTINGS" ]] || fail "installer created settings.json"
fi

# Foreign-skip: regular file dest is left untouched; installer still exits 0.
FOREIGN="$TMP/foreign-file"
echo not-a-skill > "$FOREIGN"
skip_out="$(XBGST_SURFACE_DEST="$FOREIGN" XBGST_SURFACE_WORKFLOW="$WF" XBGST_SURFACE_FLAGS="$FLAGS" bash "$INSTALL" 2>&1)" || fail "foreign dest installer rc"
[[ -f "$FOREIGN" && ! -L "$FOREIGN" ]] || fail "foreign dest must remain a regular file"
printf '%s\n' "$skip_out" | grep -F -q -- 'skip' || fail "expected skip for foreign dest: $skip_out"

echo "ok install"
