#!/usr/bin/env bash
# Health of the grok-bot xbgst-surface layer. Exit 0 only if the layer is usable.
set -euo pipefail

INTEG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok  $*"; }

ASAR="/opt/Grok Bot/resources/app.asar"
GROK_BIN="${GROK_BIN:-$HOME/.grok/bin/grok}"
DEST="${XBGST_SURFACE_DEST:-$HOME/.agents/skills/xbgst-surface}"
WF="${XBGST_SURFACE_WORKFLOW:-$HOME/.grokbot/workflows/xbgst-surface}"
FLAGS="${XBGST_SURFACE_FLAGS:-$HOME/.config/grok-bot-flags.conf}"
SETTINGS="${XBGST_SURFACE_SETTINGS:-$HOME/.grokbot/settings.json}"
PORT="${XBGST_SURFACE_CDP:-9333}"

test -x /usr/bin/grok-bot || fail "grok-bot wrapper missing"
ok wrapper
test -f "$ASAR" || fail "asar missing"
ok asar
test -x "$GROK_BIN" || fail "grok bin missing: $GROK_BIN"
ok grok-bin
test -x "$INTEG/bin/xbgst-surface-ping.sh" || fail "ping helper"
out="$("$INTEG/bin/xbgst-surface-ping.sh")"
[[ "$out" == "xbgst armed" ]] || fail "ping: $out"
ok ping
test -L "$DEST" || fail "home skill dest not a symlink: $DEST"
got=$(readlink -f "$DEST")
want=$(readlink -f "$INTEG")
[[ "$got" == "$want" ]] || fail "home dest $got != $want"
ok home-skill
test -f "$WF/SKILL.md" || fail "workflow SKILL.md missing: $WF/SKILL.md"
ok workflow
if [[ -f "$FLAGS" ]] && grep -F -q -- "--remote-debugging-port=$PORT" "$FLAGS"; then
  ok flags-cdp
else
  fail "flags missing --remote-debugging-port=$PORT ($FLAGS)"
fi
if [[ -f "$SETTINGS" ]]; then
  python3 - "$SETTINGS" <<'PY' || fail "localToolPermission not always"
import json,sys
p=sys.argv[1]
d=json.load(open(p))
perm=d.get("localToolPermission")
if perm!="always":
    raise SystemExit(f"localToolPermission={perm!r}")
PY
  ok local-tools-always
else
  fail "settings.json missing"
fi
command -v hyprctl >/dev/null || fail "hyprctl"
command -v wl-copy >/dev/null || fail "wl-copy"
ok inject-tools
if pgrep -f '/opt/Grok Bot/sand --ozone-platform' >/dev/null; then
  ok grok-bot-running
else
  echo "WARN grok-bot not running" >&2
fi
if pgrep -f 'local-exec-daemon/main.cjs' >/dev/null; then
  ok local-exec-daemon
else
  echo "WARN local-exec daemon not running" >&2
fi
if command -v curl >/dev/null && curl -sf -o /dev/null --max-time 1 "http://127.0.0.1:${PORT}/json/version"; then
  ok cdp-port
else
  echo "WARN CDP :$PORT not listening (restart grok-bot after flags)" >&2
fi
echo "ok doctor"
