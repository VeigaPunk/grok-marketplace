#!/usr/bin/env bash
# Force the 6h livepatch timer onto this marketplace stack's livepatch tree.
# Clears accidental preferred-install-root pointing at ~/Projects/grok-build-livepatch.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LP="$ROOT/plugins/xbgst-stack/livepatch"
OVERLAY="$ROOT/scripts/overlays/install-host.xbgst-stack.sh"

if [[ ! -x "$LP/scripts/install-timer.sh" ]]; then
  echo "FAIL: missing $LP/scripts/install-timer.sh" >&2
  exit 1
fi

# Keep install-host marketplace-first
if [[ -f "$OVERLAY" ]]; then
  cp -a "$OVERLAY" "$ROOT/plugins/xbgst-stack/scripts/install-host.sh"
  chmod +x "$ROOT/plugins/xbgst-stack/scripts/install-host.sh"
fi

echo "→ rebind timer ROOT=$LP"
export GROK_LIVEPATCH_ROOT="$LP"
# Drop stamp only if it points away from this LP (unless KEEP_STAMP=1)
STATE="${GROK_LIVEPATCH_STATE:-$HOME/.local/state/grok-build-livepatch}"
PREF="$STATE/preferred-install-root"
if [[ "${GROK_LIVEPATCH_KEEP_STAMP:-}" != "1" && -f "$PREF" ]]; then
  cur=$(tr -d '\r\n' <"$PREF" || true)
  if [[ -n "$cur" && "$cur" != "$LP" ]]; then
    echo "→ clearing stale preferred-install-root ($cur)"
    rm -f "$PREF"
  fi
fi

bash "$LP/scripts/install-timer.sh" --install-timer
bash "$LP/scripts/install-timer.sh" --status

exec_line=$(grep -E '^ExecStart=' "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/grok-build-livepatch.service" 2>/dev/null | head -1 || true)
if [[ "$exec_line" != *"$LP"* ]]; then
  echo "FAIL: unit ExecStart not bound to marketplace LP:" >&2
  echo "  $exec_line" >&2
  exit 1
fi
echo "→ rebind OK"
