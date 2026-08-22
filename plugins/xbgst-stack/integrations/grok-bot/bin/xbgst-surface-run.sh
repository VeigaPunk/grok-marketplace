#!/usr/bin/env bash
# Dry-run grok -p argv for xbgst. Exec only when XBGST_SURFACE_EXEC=1.
set -euo pipefail

usage() {
  echo "Usage: xbgst-surface-run.sh [--print] [--] <task...>" >&2
}

args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print) shift ;;
    --help|-h) usage; exit 0 ;;
    --) shift; args+=("$@"); break ;;
    -*) echo "unknown option: $1" >&2; usage; exit 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

GROK_BIN="${GROK_BIN:-$HOME/.grok/bin/grok}"
CWD="${XBGST_SURFACE_CWD:-/home/vgpnk/Projects/xbgst}"
if [[ ${#args[@]} -eq 0 ]]; then
  prompt="/xbgst"
else
  prompt="/xbgst ${args[*]}"
fi

cmd=("$GROK_BIN" --cwd "$CWD" --always-approve --verbatim --max-turns 64 -p "$prompt")
printf '%s\n' "${cmd[*]}"

if [[ "${XBGST_SURFACE_EXEC:-0}" == 1 ]]; then
  exec "$GROK_BIN" --cwd "$CWD" --always-approve --verbatim --max-turns 64 -p "$prompt"
fi
