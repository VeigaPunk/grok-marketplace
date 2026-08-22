#!/usr/bin/env bash
# Restart Grok Bot so grok-bot-flags.conf (CDP) applies. User-approved for this layer.
set -euo pipefail

INTEG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${XBGST_SURFACE_CDP:-9333}"
TIMEOUT="${XBGST_SURFACE_RESTART_TIMEOUT:-40}"

bash "$INTEG/install-grok-bot-surface.sh"

echo "→ stopping Grok Bot"
# Anchor at argv0 so we do not SIGTERM the installer shell (grok -c embeds this path).
pkill -TERM -f '^/opt/Grok Bot/sand( |$)' 2>/dev/null || true
for i in $(seq 1 25); do
  if ! pgrep -f '^/opt/Grok Bot/sand( |$)' >/dev/null; then
    break
  fi
  sleep 0.2
done
if pgrep -f '^/opt/Grok Bot/sand( |$)' >/dev/null; then
  echo "→ still alive, SIGKILL"
  pkill -KILL -f '^/opt/Grok Bot/sand( |$)' 2>/dev/null || true
  sleep 0.5
fi

# drop stale singleton if the previous kill left it
lock="$HOME/.config/Grok Bot/SingletonLock"
if [[ -L "$lock" || -e "$lock" ]]; then
  if ! pgrep -f '/opt/Grok Bot/sand --ozone-platform' >/dev/null; then
    rm -f "$lock" || true
  fi
fi

echo "→ starting grok-bot"
nohup grok-bot >/tmp/xbgst-surface-restart.log 2>&1 &
disown || true

deadline=$((SECONDS + TIMEOUT))
while (( SECONDS < deadline )); do
  if pgrep -f '/opt/Grok Bot/sand --ozone-platform' >/dev/null \
    && pgrep -f 'local-exec-daemon/main.cjs' >/dev/null; then
    echo "→ grok-bot + local-exec up"
    break
  fi
  sleep 0.4
done

if command -v hyprctl >/dev/null; then
  hyprctl dispatch exec grok-bot >/dev/null 2>&1 || true
  sleep 0.4
  if hyprctl clients -j 2>/dev/null | grep -q '"class": "grok-bot"'; then
    echo "→ window class:grok-bot"
  fi
fi

if curl -sf -o /dev/null --max-time 2 "http://127.0.0.1:${PORT}/json/version"; then
  echo "→ CDP http://127.0.0.1:${PORT}"
else
  echo "WARN CDP :$PORT not up yet (see /tmp/xbgst-surface-restart.log)" >&2
fi

bash "$INTEG/bin/xbgst-surface-doctor.sh" || true
echo "ok restart"
