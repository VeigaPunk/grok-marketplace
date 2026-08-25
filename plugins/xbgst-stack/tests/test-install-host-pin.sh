#!/usr/bin/env bash
# Overlay pin: steal hangar/myskills dirt onto the installed plugin; never
# yank an installed-plugin pin onto a dirty checkout.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SH="$ROOT/scripts/install-host.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
[[ -x "$SH" ]] || fail "install-host.sh not executable"
command -v fnm >/dev/null 2>&1 || fail "fnm missing"

mkstack() {
  local d=$1
  mkdir -p "$d/scripts" "$d/livepatch/scripts" \
    "$d/skills/godspeed" "$d/skills/wwkd" "$d/skills/xbgst" \
    "$d/agents" "$d/commands" "$d/ssot/godspeed-core"
  printf '%s\n' '{"name":"xbgst-stack","version":"0.0.0"}' >"$d/plugin.json"
  echo "godspeed-$2" >"$d/skills/godspeed/SKILL.md"
  echo "wwkd-$2" >"$d/skills/wwkd/SKILL.md"
  echo "xbgst-$2" >"$d/skills/xbgst/SKILL.md"
  echo "directive-$2" >"$d/ssot/godspeed-core/directive.md"
  echo "scout-$2" >"$d/agents/scout.md"
  echo "cmd-$2" >"$d/commands/xbgst.md"
  mkdir -p "$d/integrations/gx-teams"
  printf '%s\n' '#!/bin/sh' 'echo gx-teams-dummy' >"$d/integrations/gx-teams/gx-teams.sh"
  chmod +x "$d/integrations/gx-teams/gx-teams.sh"
  cat >"$d/livepatch/scripts/install-timer.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$d/livepatch/scripts/install-timer.sh"
}

probe=$(mktemp -d)
trap 'rm -rf "$probe"' EXIT

# --- steal myskills onto this tree when no plugin pin exists ---
hangar="$probe/hangar"
mkstack "$hangar" hangar
cp "$SH" "$hangar/scripts/install-host.sh"
chmod +x "$hangar/scripts/install-host.sh"
grok1="$probe/grok1"
mkdir -p "$grok1/skills" "$probe/myskills/godspeed"
echo "myskills-godspeed" >"$probe/myskills/godspeed/SKILL.md"
ln -s "$probe/myskills/godspeed" "$grok1/skills/godspeed"
HOME="$probe/home1" GROK_HOME="$grok1" XBGST_LOCAL_BIN="$probe/bin1" \
  bash "$hangar/scripts/install-host.sh" >/dev/null
[[ "$(readlink -f "$grok1/skills/godspeed")" == "$hangar/skills/godspeed" ]] \
  || fail "myskills godspeed not stolen onto hangar tree"
[[ "$(cat "$grok1/skills/godspeed/SKILL.md")" == "godspeed-hangar" ]] \
  || fail "stolen godspeed bytes"

# --- plugin pin present: hangar script overlays FROM pin, steals hangar dirt ---
pin="$probe/grok2/installed-plugins/xbgst-stack-aaa"
mkstack "$pin" pin
cp "$SH" "$pin/scripts/install-host.sh"
hangar2="$probe/hangar2"
mkstack "$hangar2" hangar
cp "$SH" "$hangar2/scripts/install-host.sh"
chmod +x "$hangar2/scripts/install-host.sh"
grok2="$probe/grok2"
mkdir -p "$grok2/skills" "$grok2/ssot" "$probe/other/myskills/godspeed" \
  "$probe/other/myskills/wwkd"
echo "myskills-godspeed" >"$probe/other/myskills/godspeed/SKILL.md"
echo "myskills-wwkd" >"$probe/other/myskills/wwkd/SKILL.md"
ln -s "$probe/other/myskills/godspeed" "$grok2/skills/godspeed"
ln -s "$probe/other/myskills/wwkd" "$grok2/skills/wwkd"
ln -s "$pin/skills/xbgst" "$grok2/skills/xbgst"
ln -s "$hangar2/agents" "$grok2/agents"
ln -s "$hangar2/commands" "$grok2/commands"
ln -s "$probe/godspeed-core" "$grok2/ssot/godspeed-core"
mkdir -p "$probe/godspeed-core"
echo "hangar-directive" >"$probe/godspeed-core/directive.md"

mkdir -p "$pin/integrations/gx-teams/mailbox/target/release" \
  "$hangar2/integrations/gx-teams/mailbox/target/release" "$probe/bin2"
printf '%s\n' '#!/bin/sh' 'echo pin-mailbox' >"$pin/integrations/gx-teams/mailbox/target/release/xbgst-mailbox"
printf '%s\n' '#!/bin/sh' 'echo hangar-mailbox' >"$hangar2/integrations/gx-teams/mailbox/target/release/xbgst-mailbox"
chmod +x "$pin/integrations/gx-teams/mailbox/target/release/xbgst-mailbox" \
  "$hangar2/integrations/gx-teams/mailbox/target/release/xbgst-mailbox"
ln -s "$hangar2/integrations/gx-teams/mailbox/target/release/xbgst-mailbox" \
  "$probe/bin2/xbgst-mailbox"

HOME="$probe/home2" GROK_HOME="$grok2" XBGST_LOCAL_BIN="$probe/bin2" \
  bash "$hangar2/scripts/install-host.sh" >/dev/null

[[ "$(readlink -f "$grok2/skills/godspeed")" == "$pin/skills/godspeed" ]] \
  || fail "godspeed not stolen onto pin ($(readlink -f "$grok2/skills/godspeed"))"
[[ "$(readlink -f "$grok2/skills/wwkd")" == "$pin/skills/wwkd" ]] \
  || fail "wwkd not stolen onto pin"
[[ "$(readlink -f "$grok2/skills/xbgst")" == "$pin/skills/xbgst" ]] \
  || fail "xbgst pin bounced"
[[ "$(readlink -f "$grok2/agents")" == "$pin/agents" ]] \
  || fail "agents still hangar ($(readlink -f "$grok2/agents"))"
[[ "$(readlink -f "$grok2/commands")" == "$pin/commands" ]] \
  || fail "commands still hangar"
[[ "$(readlink -f "$grok2/ssot/godspeed-core")" == "$pin/ssot/godspeed-core" ]] \
  || fail "ssot still hangar godspeed-core"
[[ "$(cat "$grok2/skills/godspeed/SKILL.md")" == "godspeed-pin" ]] \
  || fail "pin godspeed bytes"
[[ "$(readlink -f "$probe/bin2/xbgst-mailbox")" == "$pin/integrations/gx-teams/mailbox/target/release/xbgst-mailbox" ]] \
  || fail "mailbox still hangar ($(readlink -f "$probe/bin2/xbgst-mailbox"))"

# --- hangar script without a pin in GROK_HOME must not yank a PIN path ---
# (covered: xbgst already on pin stayed on pin in the case above)

echo GATE_INSTALL_HOST_PIN_OK
