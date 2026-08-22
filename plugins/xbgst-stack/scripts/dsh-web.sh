#!/usr/bin/env bash
# dsh web console launcher — fail-closed, loopback-only; the wrapper owns all flags.
# Canonical invocation (dsh-visual-substrate-r1-amendments §2, source-pinned):
#   DSH_HOME="$DSH_CONSOLE_HOME" dsh web --host 127.0.0.1 --port "$DSH_CONSOLE_PORT" --no-open
# SSoT: integrations/dsh/pin.env. Caller-supplied DSH_HOME is IGNORED outright.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Test-only hatch: the gate points XBGST_PIN_ENV at an alternate pin.env to exercise
# pin-poisoning paths without touching the real manifest.
PIN_ENV="${XBGST_PIN_ENV:-$ROOT/integrations/dsh/pin.env}"
[[ -r "$PIN_ENV" ]] && . "$PIN_ENV"

HOST=127.0.0.1
PORT="${DSH_CONSOLE_PORT:-}"

if ! command -v fnm >/dev/null 2>&1; then
  echo DSH_WEB_BLOCKED_NO_FNM >&2
  exit 2
fi
eval "$(fnm env --shell bash)"

# Wrapper owns all flags: zero argv pass-through, operator host/port attempts refused.
for arg in "$@"; do
  al="${arg,,}"
  case "$al" in
    --host|--host=*) echo DSH_WEB_BLOCKED_HOST >&2; exit 2 ;;
    --port|--port=*) echo DSH_WEB_BLOCKED_PORT >&2; exit 2 ;;
  esac
done

cmd="${1:-}"
case "$cmd" in up|down|status) ;; *) echo "usage: dsh-web.sh up|down|status" >&2; exit 2 ;; esac
(( $# == 1 )) || { echo "usage: dsh-web.sh up|down|status" >&2; exit 2; }

# Pin-poisoning defense (replaces the old caller-DSH_HOME BAD_HOME guard):
# console home comes ONLY from pin.env; unset/empty, realpath failure, or a resolved
# path equal to $HOME/.dsh -> refuse. Resolved-path compare, not literal-string.
resolve_home() {
  [[ -n "${DSH_CONSOLE_HOME:-}" ]] || { echo DSH_WEB_BLOCKED_BAD_PIN >&2; exit 2; }
  home_res="$(realpath -m -- "$DSH_CONSOLE_HOME" 2>/dev/null)" && [[ -n "$home_res" ]] \
    || { echo DSH_WEB_BLOCKED_BAD_PIN >&2; exit 2; }
  [[ "$home_res" != "$(realpath -m -- "$HOME/.dsh")" ]] \
    || { echo DSH_WEB_BLOCKED_BAD_PIN >&2; exit 2; }
  [[ -n "$PORT" ]] || { echo DSH_WEB_BLOCKED_BAD_PIN >&2; exit 2; }
  home="$DSH_CONSOLE_HOME"
  pidfile="$home/web.pid"
  log="$home/web.log"
}

resolve_bin() {
  if [[ -n "${DSH_BIN:-}" ]]; then bin="$DSH_BIN"
  elif [[ -x "$HOME/.cache/xbgst-dsh/smoke.aWXt/node_modules/.bin/dsh" ]]; then bin="$HOME/.cache/xbgst-dsh/smoke.aWXt/node_modules/.bin/dsh"
  else echo DSH_WEB_BLOCKED_NO_BIN >&2; exit 2; fi
  # Resolve first; basename the REAL path (a link named `dsh` pointing at an alien
  # binary fails here); executability is checked on the caller-visible path.
  bin_real="$(realpath -- "$bin" 2>/dev/null)" && [[ -n "$bin_real" ]] \
    || { echo DSH_WEB_BLOCKED_NO_BIN >&2; exit 2; }
  base_real="$(basename -- "$bin_real")"
  [[ "$base_real" == dsh || "$base_real" == bin.js ]] && [[ -x "$bin" ]] || { echo DSH_WEB_BLOCKED_NO_BIN >&2; exit 2; }
  # Spawn by resolved path so /proc/<pid>/cmdline carries bin_real verbatim.
  bin="$bin_real"
}

port_busy() { if (exec 3<>"/dev/tcp/$HOST/$PORT") 2>/dev/null; then exec 3>&- 3<&-; return 0; fi; return 1; }

kill_group() { # TERM, grace 3s, then KILL (r1 §3 down-path).
  local pid="$1" i
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  for ((i=0; i<6; i++)); do kill -0 "$pid" 2>/dev/null || return 0; sleep 0.5; done
  kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
}

case "$cmd" in
up)
  resolve_bin
  resolve_home
  mkdir -p "$home"
  # TOCTOU kill: atomic pidfile claim via noclobber BEFORE stale-purge/port checks.
  if ! ( set -o noclobber; echo "$$" > "$pidfile" ) 2>/dev/null; then
    # Claim lost: purge a stale pidfile for the next invocation, then refuse either way.
    old="$(cat -- "$pidfile" 2>/dev/null || true)"
    if [[ "$old" =~ ^[0-9]+$ ]] && kill -0 "$old" 2>/dev/null; then :; else rm -f -- "$pidfile"; fi
    echo DSH_WEB_BLOCKED_BUSY >&2; exit 2
  fi
  # We hold the pidfile. Port must be free of foreign processes before we bind it.
  if port_busy; then
    rm -f -- "$pidfile"
    echo DSH_WEB_BLOCKED_BUSY >&2; exit 2
  fi
  export DSH_HOME="$DSH_CONSOLE_HOME"
  setsid "$bin" web --host 127.0.0.1 --port "$DSH_CONSOLE_PORT" --no-open >>"$log" 2>&1 & pid=$!
  echo "$pid" >"$pidfile"
  ok=0
  for ((i=0; i<30; i++)); do # wait ≤15s for HTTP 200, else kill the group.
    if curl -fsS -o /dev/null "http://$HOST:$PORT/" 2>/dev/null; then ok=1; break; fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.5
  done
  if (( ! ok )); then
    kill_group "$pid"
    rm -f -- "$pidfile"
    echo "dsh-web: no HTTP 200 on http://$HOST:$PORT/ within 15s" >&2
    exit 2
  fi
  echo "dsh-web: up pid=$pid http://$HOST:$PORT/"
  ;;
down)
  resolve_home
  if [[ ! -f "$pidfile" ]]; then echo "dsh-web: not running" >&2; exit 0; fi
  pid="$(cat -- "$pidfile")"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then kill_group "$pid"; fi
  rm -f -- "$pidfile"
  # Retry port release: 5 x 0.5s before declaring failure (P1: no single-shot check).
  for ((i=0; i<5; i++)); do
    port_busy || break
    sleep 0.5
  done
  if port_busy; then echo "dsh-web: port $PORT still bound after down" >&2; exit 1; fi
  echo "dsh-web: down"
  ;;
status)
  resolve_bin
  resolve_home
  [[ -f "$pidfile" ]] || { echo "dsh-web: not running" >&2; exit 1; }
  pid="$(cat -- "$pidfile")"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null || { echo "dsh-web: not running" >&2; exit 1; }
  port_busy || { echo "dsh-web: port $PORT not listening" >&2; exit 1; }
  # Identity: /proc cmdline split on NUL; require an element exactly equal to the
  # resolved bin path immediately followed by a `web` element (arg-exact, no glob).
  [[ -r "/proc/$pid/cmdline" ]] || { echo "dsh-web: unreadable /proc/$pid/cmdline" >&2; exit 1; }
  ident=0; prev=""
  while IFS= read -r a; do
    if [[ "$prev" == "$bin_real" && "$a" == web ]]; then ident=1; break; fi
    prev="$a"
  done < <(tr '\0' '\n' <"/proc/$pid/cmdline")
  (( ident )) || { echo "dsh-web: pid $pid is not $bin_real web" >&2; exit 1; }
  echo ok
  ;;
esac
