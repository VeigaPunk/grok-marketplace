#!/usr/bin/env bash
# Print-first hangar wrapper: Grok L1 → xbgst-cursor L2-fsd.
# Forwards to xbgst-cursor/bin/xbgst-cursor-run.sh. Exec only if XBGST_CURSOR_EXEC=1.
# Do not copy prime-agent-l2.sh XAI/cwd guards.
set -euo pipefail

usage() {
  echo "Usage: cursor-agent-l2.sh [--print] [--model <cli-id>] [--] <task...>" >&2
}

args=()
model_flag=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print) shift ;;
    --help|-h) usage; exit 0 ;;
    --model)
      shift
      if [[ $# -lt 1 || "$1" == -* ]]; then
        echo "missing --model value (pass a cursor-agent catalog CLI-id)" >&2
        exit 2
      fi
      model_flag="$1"
      shift
      ;;
    --model=*)
      model_flag="${1#--model=}"
      shift
      if [[ -z "$model_flag" ]]; then
        echo "missing --model value (pass a cursor-agent catalog CLI-id)" >&2
        exit 2
      fi
      ;;
    --mode|--mode=*)
      echo "refusing --mode (consult stays PATH xask --mode ask; L2-fsd is cursor-agent -p)" >&2
      exit 2
      ;;
    --force|-f)
      echo "refusing --force" >&2
      exit 2
      ;;
    --yolo)
      echo "refusing --yolo" >&2
      exit 2
      ;;
    --plugin-dir|--plugin-dir=*)
      echo "refusing --plugin-dir" >&2
      exit 2
      ;;
    --) shift; args+=("$@"); break ;;
    -*) echo "unknown option: $1" >&2; usage; exit 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

bin="${CURSOR_AGENT_BIN:-}"
bin="${bin#"${bin%%[![:space:]]*}"}"
bin="${bin%"${bin##*[![:space:]]}"}"
bin="${bin:-cursor-agent}"
CURSOR_AGENT_BIN="$bin"
if [[ "$(basename -- "$bin")" == [Aa][Gg][Ee][Nn][Tt] ]]; then
  echo "refusing argv0=agent (use cursor-agent)" >&2
  exit 2
fi

# Workspace is pinned to the orch tree. Refuse spoofed XBGST_CURSOR_CWD
# (e.g. the surface tree). Documented allow: XBGST_CURSOR_CWD_ALLOW,
# colon-separated extra roots for operator overrides.
ORCH_PIN="/home/vgpnk/Projects/xbgst/xbgst-cursor"
ORCH_TREE="${XBGST_CURSOR_ORCH:-$ORCH_PIN}"
ORCH_RUN="${XBGST_CURSOR_RUN:-$ORCH_TREE/bin/xbgst-cursor-run.sh}"
[[ -x "$ORCH_RUN" ]] || { echo "BLOCKED: missing xbgst-cursor run helper: $ORCH_RUN" >&2; exit 2; }

_cwd_under() {
  local cand="$1" root="$2" c r
  c=$(realpath -m -- "$cand")
  r=$(realpath -m -- "$root")
  [[ "$c" == "$r" || "$c" == "$r"/* ]]
}

_cwd="${XBGST_CURSOR_CWD:-$ORCH_TREE}"
_allow=0
if _cwd_under "$_cwd" "$ORCH_PIN"; then
  _allow=1
else
  IFS=':' read -ra _allow_roots <<<"${XBGST_CURSOR_CWD_ALLOW:-}"
  for _r in "${_allow_roots[@]}"; do
    [[ -n "$_r" ]] || continue
    if _cwd_under "$_cwd" "$_r"; then
      _allow=1
      break
    fi
  done
fi
if [[ "$_allow" -ne 1 ]]; then
  echo "refusing XBGST_CURSOR_CWD=$_cwd (pinned to $ORCH_PIN)" >&2
  exit 2
fi
if ! _cwd_under "$ORCH_RUN" "$ORCH_PIN"; then
  echo "refusing XBGST_CURSOR_RUN=$ORCH_RUN (pinned to $ORCH_PIN)" >&2
  exit 2
fi
export XBGST_CURSOR_CWD="$(realpath -m -- "$_cwd")"
# Catalog pin is cursor-agent --model, not xask --model-id. Flag/env both land on the orch helper.
if [[ -n "$model_flag" ]]; then
  export XBGST_CURSOR_MODEL="$model_flag"
  set -- --model "$model_flag" "$@"
fi

if [[ ${#args[@]} -eq 0 ]]; then
  exec bash "$ORCH_RUN" --print "$@"
fi
exec bash "$ORCH_RUN" --print "$@" -- "${args[@]}"
