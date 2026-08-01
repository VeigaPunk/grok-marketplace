#!/usr/bin/env bash
# Copy standalone grok-build-livepatch scripts/systemd/README into nested plugin trees.
# Usage: LIVEPATCH_SRC=~/Projects/grok-build-livepatch ./scripts/sync-livepatch.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${LIVEPATCH_SRC:-$HOME/Projects/grok-build-livepatch}"
if [[ ! -x "$SRC/scripts/check-and-patch.sh" ]]; then
  echo "LIVEPATCH_SRC missing or incomplete: $SRC" >&2
  exit 1
fi
for dest in \
  "$ROOT/plugins/xbgst-stack/livepatch" \
  "$ROOT/plugins/grok-build-livepatch"
do
  [[ -d "$dest" ]] || continue
  echo "→ sync $SRC → $dest"
  for f in \
    scripts/check-and-patch.sh \
    scripts/install-timer.sh \
    scripts/gates.sh \
    scripts/publish.sh \
    systemd/grok-build-livepatch.service \
    systemd/grok-build-livepatch.timer \
    README.md
  do
    [[ -f "$SRC/$f" ]] || continue
    mkdir -p "$(dirname "$dest/$f")"
    cp -a "$SRC/$f" "$dest/$f"
  done
done
echo "done. Review git diff, run ./scripts/smoke-gates.sh, then commit."
