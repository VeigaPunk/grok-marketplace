#!/usr/bin/env bash
# Marketplace-safe: sync livepatch payload into stack trees WITHOUT rewriting install-host.
# (Standalone sync-stack-livepatch.sh prefers Projects and clobbers marketplace-first host.)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: sync-stack-livepatch.sh [--help|-h] [--no-timer]

Copy scripts/, systemd/, patches/ from this livepatch tree into sibling/known
stack livepatch dirs. Does NOT rewrite xbgst-stack install-host.sh.

  --no-timer   skip install-timer rebind
EOF
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
esac

NO_TIMER=0
case "${1:-}" in
  --no-timer) NO_TIMER=1 ;;
  "") ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sync_tree() {
  local dest="$1"
  [[ -d "$dest" ]] || return 0
  mkdir -p "$dest/scripts" "$dest/systemd" "$dest/patches"
  cp -a "$ROOT/scripts/"*.sh "$dest/scripts/" 2>/dev/null || true
  # re-apply marketplace-safe copy of this script after cp
  cp -a "${BASH_SOURCE[0]}" "$dest/scripts/sync-stack-livepatch.sh"
  cp -a "$ROOT/systemd/"* "$dest/systemd/" 2>/dev/null || true
  cp -a "$ROOT/patches/"* "$dest/patches/" 2>/dev/null || true
  chmod +x "$dest/scripts/"*.sh 2>/dev/null || true
  echo "synced → $dest (install-host untouched)"
}

# If we are the nest under marketplace, also mirror to plugin twin
MP_ROOT=""
case "$ROOT" in
  */plugins/xbgst-stack/livepatch) MP_ROOT="$(cd "$ROOT/../../.." && pwd)" ;;
  */plugins/grok-build-livepatch) MP_ROOT="$(cd "$ROOT/../.." && pwd)" ;;
esac

if [[ -n "$MP_ROOT" && -f "$MP_ROOT/.grok-plugin/marketplace.json" ]]; then
  sync_tree "$MP_ROOT/plugins/xbgst-stack/livepatch"
  sync_tree "$MP_ROOT/plugins/grok-build-livepatch"
  # restore marketplace install-host overlay
  if [[ -f "$MP_ROOT/scripts/overlays/install-host.xbgst-stack.sh" ]]; then
    cp -a "$MP_ROOT/scripts/overlays/install-host.xbgst-stack.sh" \
      "$MP_ROOT/plugins/xbgst-stack/scripts/install-host.sh"
    chmod +x "$MP_ROOT/plugins/xbgst-stack/scripts/install-host.sh"
    echo "restored marketplace install-host overlay"
  fi
else
  sync_tree "$ROOT"
fi

if [[ "$NO_TIMER" -eq 0 ]]; then
  LP="$ROOT"
  if [[ -x "$LP/scripts/install-timer.sh" ]]; then
    echo "→ rebind timer to $LP"
    GROK_LIVEPATCH_ROOT="$LP" bash "$LP/scripts/install-timer.sh" || true
  fi
fi

echo "done (marketplace-safe sync-stack-livepatch)"
