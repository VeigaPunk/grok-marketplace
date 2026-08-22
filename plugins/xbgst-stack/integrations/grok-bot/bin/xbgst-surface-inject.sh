#!/usr/bin/env bash
# Paste stdin/file into the live Grok Bot composer via Hyprland.
# Proven on this host: focuswindow class:grok-bot + SHIFT+Insert + Return.
# Does not start grok -p. Does not write ~/.grokbot/settings.json.
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage: xbgst-surface-inject.sh [--dry-run] [--no-submit] [--click X,Y] [FILE|-]

Reads paste text from FILE, stdin, or - . Default FILE is stdin when piped.
EOF
}

DRY=0
SUBMIT=1
CLICK=""
FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --no-submit) SUBMIT=0; shift ;;
    --click)
      CLICK="${2:-}"
      [[ -n "$CLICK" ]] || { echo "missing --click X,Y" >&2; exit 2; }
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "unknown option: $1" >&2; usage; exit 2 ;;
    *) FILE="$1"; shift; break ;;
  esac
done

if [[ -z "$FILE" ]]; then
  if [[ -t 0 ]]; then
    echo "no paste on stdin; pass a FILE" >&2
    usage
    exit 2
  fi
  FILE="-"
fi

run() {
  if [[ "$DRY" -eq 1 ]]; then
    printf '+ %s\n' "$*"
    return 0
  fi
  "$@"
}

command -v hyprctl >/dev/null || { echo "hyprctl missing" >&2; exit 1; }
command -v wl-copy >/dev/null || { echo "wl-copy missing" >&2; exit 1; }

if [[ "$DRY" -eq 1 ]]; then
  echo "dry-run inject class:grok-bot SHIFT+Insert"
  echo "hyprctl dispatch focuswindow class:grok-bot"
  if [[ -n "$CLICK" ]]; then
    echo "hyprctl dispatch movecursor ${CLICK%,*} ${CLICK#*,}"
    echo "hyprctl dispatch sendshortcut , mouse:272, activewindow"
  fi
  echo "wl-copy --type text/plain"
  echo "hyprctl dispatch sendshortcut SHIFT, Insert, activewindow"
  if [[ "$SUBMIT" -eq 1 ]]; then
    echo "hyprctl dispatch sendshortcut CTRL, Return, activewindow"
  fi
  exit 0
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
if [[ "$FILE" == "-" ]]; then
  cat >"$tmp"
else
  cat "$FILE" >"$tmp"
fi
[[ -s "$tmp" ]] || { echo "empty paste" >&2; exit 1; }

run hyprctl dispatch focuswindow class:grok-bot >/dev/null
sleep 0.15
if [[ -n "$CLICK" ]]; then
  run hyprctl dispatch movecursor "${CLICK%,*}" "${CLICK#*,}" >/dev/null
  sleep 0.08
  run hyprctl dispatch sendshortcut ", mouse:272, activewindow" >/dev/null || true
  sleep 0.12
fi
run wl-copy --type text/plain <"$tmp"
sleep 0.05
run hyprctl dispatch sendshortcut "SHIFT, Insert, activewindow" >/dev/null
sleep 0.25
if [[ "$SUBMIT" -eq 1 ]]; then
  # grok-bot treats bare Return as newline in a multiline composer
  run hyprctl dispatch sendshortcut "CTRL, Return, activewindow" >/dev/null
fi
echo "injected $(wc -c <"$tmp") bytes into grok-bot"
