#!/usr/bin/env bash
# Sync livepatch payload from the standalone clone into this marketplace.
# Default source: $HOME/Projects/grok-build-livepatch (override STANDALONE=).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAND="${STANDALONE:-$HOME/Projects/grok-build-livepatch}"
NEST="$ROOT/plugins/xbgst-stack/livepatch"
PLUG="$ROOT/plugins/grok-build-livepatch"

usage() {
  cat <<'EOF'
Usage: sync-livepatch-from-standalone.sh [--help|-h] [--check]

  (default)  rsync scripts/patches/systemd/docs/README from standalone into
             plugins/xbgst-stack/livepatch and plugins/grok-build-livepatch.
  --check    exit 0 if already in sync (no writes); exit 1 if drift.
  STANDALONE=/path  override source clone (default ~/Projects/grok-build-livepatch).

Does not touch: plugin.json, marketplace/, install-host.sh, root .github/.
EOF
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
esac

if [[ ! -d "$STAND/scripts" || ! -d "$STAND/patches" ]]; then
  echo "FAIL: standalone livepatch not found at $STAND" >&2
  exit 1
fi

check_drift() {
  # Payload that must match standalone (docs/README may carry marketplace notes).
  # Exclude sync-stack-livepatch.sh — marketplace replaces it with a safe overlay.
  local dest=$1
  local drift=0
  for sub in patches systemd; do
    if ! diff -rq "$STAND/$sub" "$dest/$sub" >/dev/null 2>&1; then
      echo "DRIFT $dest/$sub"
      drift=1
    fi
  done
  # scripts: compare file-by-file except marketplace-owned sync-stack-livepatch.sh
  local f base
  for f in "$STAND/scripts/"*; do
    [[ -f "$f" ]] || continue
    base=$(basename "$f")
    if [[ "$base" == "sync-stack-livepatch.sh" ]]; then
      continue
    fi
    if ! diff -q "$f" "$dest/scripts/$base" >/dev/null 2>&1; then
      echo "DRIFT $dest/scripts/$base"
      drift=1
    fi
  done
  return "$drift"
}

if [[ "${1:-}" == "--check" ]]; then
  fail=0
  check_drift "$NEST" || fail=1
  check_drift "$PLUG" || fail=1
  if [[ "$fail" -ne 0 ]]; then
    echo "FAIL: nested livepatch drifts from $STAND ($(git -C "$STAND" rev-parse --short HEAD 2>/dev/null || echo unknown))"
    exit 1
  fi
  echo "OK  livepatch in sync with $STAND @ $(git -C "$STAND" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  exit 0
fi

TIP=$(git -C "$STAND" rev-parse --short HEAD 2>/dev/null || echo unknown)
MSG=$(git -C "$STAND" log -1 --oneline 2>/dev/null || echo "")
echo "→ sync from $STAND @ $TIP $MSG"

for DEST in "$NEST" "$PLUG"; do
  mkdir -p "$DEST"
  rsync -a --delete "$STAND/scripts/" "$DEST/scripts/"
  rsync -a --delete "$STAND/patches/" "$DEST/patches/"
  rsync -a --delete "$STAND/systemd/" "$DEST/systemd/"
  rsync -a --delete "$STAND/docs/" "$DEST/docs/"
  rsync -a "$STAND/README.md" "$DEST/README.md"
  for lic in LICENSE-APACHE LICENSE-MIT; do
    [[ -f "$STAND/$lic" ]] && rsync -a "$STAND/$lic" "$DEST/"
  done
  if [[ -d "$STAND/.github/workflows" ]]; then
    mkdir -p "$DEST/.github/workflows"
    rsync -a "$STAND/.github/workflows/" "$DEST/.github/workflows/"
    for wf in "$DEST/.github/workflows/"*.yml; do
      [[ -f "$wf" ]] || continue
      if ! head -3 "$wf" | grep -q 'NOT executed by GitHub'; then
        tmp=$(mktemp)
        printf '%s\n' \
          '# NOTE: Nested workflow is NOT executed by GitHub under grok-marketplace.' \
          '# Active CI: repo-root .github/workflows/livepatch-watch.yml' \
          '' | cat - "$wf" >"$tmp"
        mv "$tmp" "$wf"
      fi
    done
  fi
  chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true
  # Standalone ships sync-stack-livepatch.sh that rewrites install-host to prefer
  # Projects/. Replace with marketplace-safe variant (never clobbers install-host).
  if [[ -f "$ROOT/scripts/overlays/sync-stack-livepatch.marketplace-safe.sh" ]]; then
    cp -a "$ROOT/scripts/overlays/sync-stack-livepatch.marketplace-safe.sh" \
      "$DEST/scripts/sync-stack-livepatch.sh"
    chmod +x "$DEST/scripts/sync-stack-livepatch.sh"
  fi
  echo "  synced → $DEST"
done

# Always restore marketplace-first install-host (never let nested tools rewrite it).
if [[ -f "$ROOT/scripts/overlays/install-host.xbgst-stack.sh" ]]; then
  cp -a "$ROOT/scripts/overlays/install-host.xbgst-stack.sh" \
    "$ROOT/plugins/xbgst-stack/scripts/install-host.sh"
  chmod +x "$ROOT/plugins/xbgst-stack/scripts/install-host.sh"
  echo "→ restored install-host from scripts/overlays/install-host.xbgst-stack.sh"
fi

printf '%s\n' "$TIP" >"$ROOT/plugins/xbgst-stack/livepatch/.standalone-tip"
printf '%s\n' "$TIP" >"$PLUG/.standalone-tip"
echo "→ wrote .standalone-tip=$TIP"
echo "→ next: ./scripts/smoke-gates.sh && ./scripts/ship-check.sh && commit on main"
