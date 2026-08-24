#!/usr/bin/env bash
# Prototype: detach an L1 clone in a gx-teams tmux window at another cwd.
# The clone is a real Grok L1 (may /xbgst, Pareto, APPROVED, ship there).
# This process does not wait. Never nuke operator tmux sessions 0/1.
set -euo pipefail

STACK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GX="${GX_TEAMS:-$STACK/integrations/gx-teams/gx-teams.sh}"
# Resolve: GROK_BIN → grok-titanium (livepatch, PATH) → grok. Same ban set.
if [[ -z "${GROK_BIN:-}" ]]; then
  if [[ -x "$HOME/.local/bin/grok-titanium" ]]; then
    GROK_BIN="$HOME/.local/bin/grok-titanium"
  elif command -v grok-titanium >/dev/null 2>&1; then
    GROK_BIN="$(command -v grok-titanium)"
  elif command -v grok >/dev/null 2>&1; then
    GROK_BIN="$(command -v grok)"
  else
    GROK_BIN="$HOME/.grok/bin/grok"
  fi
fi
DRY=0
PING=0
TEAM="clone"
NAME=""
CWD=""
TASK=""

usage() {
  cat <<'EOF'
Usage:
  xbgst-clone-l1.sh [--dry-run] [--ping] [--team T] [--name N] --cwd DIR -- <task>

  --dry-run  print argv; do not spawn
  --ping     grok -p 'Reply with exactly: CLONE_L1_OK' instead of /xbgst
  --cwd DIR  target working directory (must exist)
  --         rest is the child L1 task (passed to /xbgst)

Team name cannot be 0 or 1 (operator sessions).
Grok has no --no-leader; each clone gets --leader-socket under /tmp.
Pane PWD is set with env -C so tools match grok --cwd.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --ping) PING=1; shift ;;
    --team) TEAM="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --cwd) CWD="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    --) shift; TASK="$*"; break ;;
    *)
      if [[ -z "$CWD" && -d "$1" ]]; then
        CWD="$1"
        shift
      else
        echo "unknown arg: $1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

[[ -n "$CWD" ]] || { echo "xbgst-clone-l1: --cwd required" >&2; exit 2; }
[[ -d "$CWD" ]] || { echo "xbgst-clone-l1: cwd missing: $CWD" >&2; exit 2; }
ABS=$(readlink -f "$CWD")
HERE=$(readlink -f "${PWD:-.}")
if [[ "$TEAM" == "0" || "$TEAM" == "1" ]]; then
  echo "xbgst-clone-l1: refuse team 0|1 (operator tmux)" >&2
  exit 2
fi
[[ -x "$GX" ]] || { echo "xbgst-clone-l1: gx-teams missing: $GX" >&2; exit 2; }
[[ -x "$GROK_BIN" ]] || { echo "xbgst-clone-l1: grok missing: $GROK_BIN" >&2; exit 2; }

if [[ -z "$NAME" ]]; then
  base=$(basename "$ABS")
  base=${base//[^A-Za-z0-9_-]/_}
  base=${base:0:24}
  [[ -n "$base" ]] || base="repo"
  NAME="gx-l1-${base}-$$"
fi

if [[ "$PING" -eq 1 ]]; then
  PROMPT='Reply with exactly: CLONE_L1_OK'
else
  [[ -n "$TASK" ]] || { echo "xbgst-clone-l1: task required after --" >&2; exit 2; }
  PROMPT="/xbgst $TASK"
fi

if [[ -n "${XBGST_CLONE_LEADER_SOCK:-}" ]]; then
  SOCK="$XBGST_CLONE_LEADER_SOCK"
else
  sockf=$(mktemp /tmp/xbgst-clone-XXXXXX)
  rm -f "$sockf"
  SOCK="${sockf}.sock"
fi

# Headless. Ping is oneshot (no subagents). Full clone IS a judge — keep subagents.
# env -C so pane PWD matches --cwd (gx-teams does not pass tmux -c).
# GX_L1=1 on the env prefix so the pane grok sees it even if tmux -e is an allowlist.
CMD=( env -C "$ABS" GX_L1=1 "$GROK_BIN" --cwd "$ABS" --always-approve --verbatim --leader-socket "$SOCK" )
if [[ "$PING" -eq 1 ]]; then
  CMD+=( --no-subagents )
fi
CMD+=( -p "$PROMPT" )

if [[ "$ABS" == "$HERE" ]]; then
  echo "xbgst-clone-l1: WARN same cwd as parent (explicit clone A/B); autonomous default is /xbgst-orch" >&2
fi

if [[ "$DRY" -eq 1 ]]; then
  printf 'DRY cwd=%s here=%s team=%s name=%s sock=%s skip_godspeed=1 gx_l1=1 bin=%s\n' "$ABS" "$HERE" "$TEAM" "$NAME" "$SOCK" "$GROK_BIN"
  printf 'DRY gx-teams spawn --team %s --name %s -- cmd' "$TEAM" "$NAME"
  printf ' %q' "${CMD[@]}"
  printf '\n'
  exit 0
fi

# Do not let gx-teams wrap -p with directive.md: /xbgst must load skill xbgst.
# GX_L1=1 on the parent so id_env can forward it. Do not set GX_XBGST_ROLE=specialist.
export GX_TEAMS_SKIP_GODSPEED=1
export GX_L1=1
echo "CLONE_L1_SPAWNING team=$TEAM name=$NAME cwd=$ABS sock=$SOCK skip_godspeed=1 gx_l1=1" >&2
out=$("$GX" spawn --team "$TEAM" --name "$NAME" -- cmd "${CMD[@]}")
printf 'CLONE_L1_SPAWNED %s cwd=%s\n' "$out" "$ABS"
