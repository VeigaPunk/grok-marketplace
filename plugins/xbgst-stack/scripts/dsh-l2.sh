#!/usr/bin/env bash
set -euo pipefail

if ! command -v fnm >/dev/null 2>&1; then
  echo DSH_TICK_BLOCKED_NO_FNM >&2
  exit 2
fi
eval "$(fnm env --shell bash)"

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
for arg in "$@"; do
  al="${arg,,}"
  case "$al" in
    *general-purpose*|explore|/explore|subagent_type=explore|subagent_type:explore)
      echo DSH_TICK_BLOCKED_BANNED_TYPE >&2; exit 2 ;;
  esac
  [[ "$al" == /login* ]] && { echo DSH_TICK_BLOCKED_LOGIN >&2; exit 2; }
done

profile=""
for ((i=1; i<=$#; i++)); do
  eval "a=\${$i}"
  case "$a" in
    --profile=*) profile="${a#*=}" ;;
    --profile)
      if (( i < $# )); then ((i++)); eval "profile=\${$i}"; else profile=""; fi ;;
  esac
done
[[ "$profile" == xbgst-worker ]] || { echo DSH_TICK_BLOCKED_PROFILE >&2; exit 2; }

cwd="$(pwd -P 2>/dev/null || pwd)"
case "$cwd" in /tmp/xbgst-dsh-*) ;; *) echo DSH_TICK_BLOCKED_CWD >&2; exit 2;; esac

if [[ -n "${DSH_BIN:-}" ]]; then bin="$DSH_BIN"
elif [[ -x "$HOME/.cache/xbgst-dsh/smoke.aWXt/node_modules/.bin/dsh" ]]; then bin="$HOME/.cache/xbgst-dsh/smoke.aWXt/node_modules/.bin/dsh"
else echo DSH_TICK_BLOCKED_NO_BIN >&2; exit 2; fi
[[ "$(basename -- "$bin")" == dsh && -x "$bin" ]] || { echo DSH_TICK_BLOCKED_NO_BIN >&2; exit 2; }

cleanup=0
if [[ -n "${XBGST_DSH_HOME:-}" ]]; then
  # Runs-prefix allowlist (r1 §1): resolved XBGST_DSH_HOME must live under the runs
  # root — never console-home, never the repo, never $HOME/.dsh.
  runs_root="$(realpath -m -- "${DSH_RUNS_ROOT:-/home/vgpnk/.cache/xbgst-dsh/runs}")"
  home_res="$(realpath -m -- "$XBGST_DSH_HOME")"
  [[ "$home_res" == "$runs_root"/* ]] || { echo DSH_TICK_BLOCKED_XBGST_HOME >&2; exit 2; }
  home="$XBGST_DSH_HOME"; mkdir -p "$home"
else home="$(mktemp -d /tmp/xbgst-dsh-home.XXXXXX)"; cleanup=1; fi
trap '(( cleanup )) && rm -rf -- "$home"' EXIT
mkdir -p "$home/profiles/xbgst-worker"
cp -- "$ROOT/integrations/dsh/profiles/xbgst-worker/package.json" "$home/profiles/xbgst-worker/package.json"
cp -- "$ROOT/integrations/dsh/profiles/xbgst-worker/cordis.patch.yml" "$home/profiles/xbgst-worker/cordis.patch.yml"
export DSH_HOME="$home"

# rc.8 commander forwards post-operand flags to the headless app, which rejects
# them (F4: `error: unknown option '--patch'`). Spawn argv is flag-first: every
# option flag (--profile + its value, the assembled --patch pair) precedes the
# positional task operand; operand-class tokens keep their relative order.
pre=(); post=(); argv=("$@"); i=0
while (( i < ${#argv[@]} )); do
  a="${argv[$i]}"
  if [[ "$a" == --profile && $((i+1)) -lt ${#argv[@]} ]]; then
    pre+=("$a" "${argv[$((i+1))]}"); ((i+=2)); continue
  elif [[ "$a" == -* ]]; then pre+=("$a")
  else post+=("$a"); fi
  ((i++))
done
args=("${pre[@]}" --patch "$home/profiles/xbgst-worker/cordis.patch.yml" "${post[@]}")
if [[ "${DSH_TIMEOUT_SECS:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk "BEGIN{exit !(${DSH_TIMEOUT_SECS:-0}>0)}"; then
  setsid "$bin" "${args[@]}" & pid=$!
  # fds redirected: a backgrounded watcher must never hold the caller's pipe.
  ( sleep "$DSH_TIMEOUT_SECS"; kill -TERM -- "-$pid" 2>/dev/null || true ) >/dev/null 2>&1 & timer=$!
  rc=0; wait "$pid" || rc=$?
  # SIGKILL, not TERM: the watcher defers TERM while blocked in sleep.
  kill -9 "$timer" 2>/dev/null || true; wait "$timer" 2>/dev/null || true; exit "$rc"
fi
exec "$bin" "${args[@]}"
