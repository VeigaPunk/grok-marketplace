#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
# ${TMUX##*,} is socket index, not session name (fake-greens when name is 1).
if grep -Eq 'TMUX##\*,|\$\{TMUX##' "$ROOT/gx-teams.sh"; then
  echo 'FAIL: parent must not use ${TMUX##*,}' >&2
  exit 1
fi
if ! grep -Fq "display-message -t \"\$TMUX_PANE\" -p '#{session_name}'" "$ROOT/gx-teams.sh"; then
  echo 'FAIL: missing session_name parent resolution' >&2
  exit 1
fi
cleanup() { "$GT" nuke --team id >/dev/null 2>&1 || true; }
trap cleanup EXIT
if tmux has-session -t '=gx-teams-id' 2>/dev/null; then "$GT" nuke --team id; fi
expect_sess=$(tmux display-message -t "${TMUX_PANE}" -p '#{session_name}')
[[ -n "$expect_sess" ]]
[[ "$expect_sess" != %* ]]
out=$("$GT" spawn --team id --name gx-labrat-ping -- cmd echo PING-OK)
pane=$(awk '{print $2}' <<<"$out")
pid=$(awk '{print $3}' <<<"$out")
envdump=$(tr '\0' '\n' < /proc/"$pid"/environ)
grep -qx "GX_TEAM=id" <<<"$envdump"
grep -qx "GX_TEAMMATE_NAME=gx-labrat-ping" <<<"$envdump"
grep -qx "GX_TEAMMATE_ID=gx-labrat-ping@id" <<<"$envdump"
grep -qx "GX_PARENT_SESSION=${expect_sess}" <<<"$envdump"
if grep -qx "GX_PARENT_SESSION=${TMUX_PANE}" <<<"$envdump"; then
  echo "FAIL: GX_PARENT_SESSION is pane ${TMUX_PANE}" >&2
  "$GT" nuke --team id || true
  exit 1
fi
title=$(tmux display-message -t "$pane" -p '#{pane_title}')
[[ "$title" == gx-labrat-ping ]]
"$GT" nuke --team id
echo GATE_M03_OK
