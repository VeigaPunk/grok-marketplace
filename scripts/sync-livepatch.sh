#!/usr/bin/env bash
# Thin alias → sync-livepatch-from-standalone.sh
# LIVEPATCH_SRC=… maps to STANDALONE=…
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${LIVEPATCH_SRC:-}" ]]; then
  export STANDALONE="$LIVEPATCH_SRC"
fi
exec bash "$ROOT/scripts/sync-livepatch-from-standalone.sh" "$@"
