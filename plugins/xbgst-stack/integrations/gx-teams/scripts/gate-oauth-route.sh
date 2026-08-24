#!/usr/bin/env bash
# Cheap offline gate: cmd spawn grok is wrapped with grok-oauth-route when present.
# No live grok -p. No tmux.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$GT" ]] || fail "missing $GT"

python3 - "$GT" <<'PY' || fail "source strings missing"
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
if "command -v grok-oauth-route" not in text:
    raise SystemExit("missing command -v grok-oauth-route")
if '("grok-oauth-route" "wrap" "--"' not in text:
    raise SystemExit("missing grok-oauth-route wrap -- prefix")
i = text.find("inject_godspeed_into_grok_prompt command_argv")
j = text.find("maybe_wrap_grok_oauth_route command_argv")
if i < 0 or j < 0 or i >= j:
    raise SystemExit("cmd_spawn must inject godspeed then wrap oauth-route")
print("source_strings_ok")
PY

CANON=""
for cand in \
  "$ROOT/../../ssot/godspeed-core/directive.md" \
  "${HOME}/.grok/ssot/godspeed-core/directive.md"
do
  if [[ -f "$cand" ]]; then
    CANON="$cand"
    break
  fi
done
[[ -n "$CANON" ]] || fail "canonical directive missing"

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT

export HOME="$TMP_DIR/home"
export GX_TEAMS_STATE="$TMP_DIR/state"
export GX_TEAMS_GODSPEED_DIRECTIVE="$CANON"
export GX_TEAMS_SOURCE_ONLY=1
# shellcheck source=../gx-teams.sh
source "$GT"

command -v maybe_wrap_grok_oauth_route >/dev/null 2>&1 \
  || fail "maybe_wrap_grok_oauth_route missing"

# Absent helper: pass-through (do not prefix).
(
  export PATH="/usr/bin:/bin"
  command -v grok-oauth-route >/dev/null 2>&1 && fail "sanitized PATH still has grok-oauth-route"
  argv=(grok -p 'x')
  maybe_wrap_grok_oauth_route argv
  [[ "${argv[0]}" == grok ]] || fail "absent helper mutated argv0=${argv[0]}"
  [[ ${#argv[@]} -eq 3 ]] || fail "absent helper changed argc=${#argv[@]}"
  argv=(/usr/bin/grok --always-approve -p 'y')
  maybe_wrap_grok_oauth_route argv
  [[ "${argv[0]}" == /usr/bin/grok ]] || fail "absent helper mutated path grok"
)

STUB="$TMP_DIR/bin"
mkdir -p "$STUB"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$STUB/grok-oauth-route"
chmod +x "$STUB/grok-oauth-route"
export PATH="$STUB:/usr/bin:/bin"
command -v grok-oauth-route >/dev/null 2>&1 || fail "stub helper not on PATH"

argv=(grok -p 'x')
maybe_wrap_grok_oauth_route argv
[[ "${argv[0]}" == grok-oauth-route ]] || fail "present helper argv0=${argv[0]}"
[[ "${argv[1]}" == wrap ]] || fail "present helper argv1=${argv[1]}"
[[ "${argv[2]}" == -- ]] || fail "present helper argv2=${argv[2]}"
[[ "${argv[3]}" == grok ]] || fail "present helper did not keep grok"
[[ "${argv[4]}" == -p ]] || fail "present helper dropped -p"
[[ "${argv[5]}" == x ]] || fail "present helper dropped prompt"

argv=(/usr/bin/grok --always-approve -p 'y')
maybe_wrap_grok_oauth_route argv
[[ "${argv[0]}" == grok-oauth-route && "${argv[3]}" == /usr/bin/grok ]] \
  || fail "path grok not wrapped"

# Non-grok cmd spawn must not wrap. env-prefix grok must wrap (gate-m02 shape).
argv=(echo PING-OK)
maybe_wrap_grok_oauth_route argv
[[ "${argv[0]}" == echo && ${#argv[@]} -eq 2 ]] || fail "echo wrapped"
argv=(env GROK_SUBAGENTS=0 grok -p 'z')
maybe_wrap_grok_oauth_route argv
[[ "${argv[0]}" == grok-oauth-route && "${argv[3]}" == env && "${argv[5]}" == grok ]] \
  || fail "env-prefix grok not wrapped"

# Wrap is idempotent.
argv=(grok-oauth-route wrap -- grok -p 'x')
maybe_wrap_grok_oauth_route argv
[[ "${argv[0]}" == grok-oauth-route && "${argv[3]}" == grok && ${#argv[@]} -eq 6 ]] \
  || fail "double-wrap"

# Godspeed inject still rewrites -p; wrap prefixes after inject.
argv=(/usr/bin/grok --no-leader -p $'role task')
inject_godspeed_into_grok_prompt argv
maybe_wrap_grok_oauth_route argv
[[ "${argv[0]}" == grok-oauth-route ]] || fail "inject+wrap missing prefix"
[[ "${argv[3]}" == /usr/bin/grok ]] || fail "inject+wrap lost grok"
PROMPT="${argv[-1]}" python3 - "$CANON" <<'PY'
import os
import pathlib
import sys

directive = pathlib.Path(sys.argv[1]).read_bytes()
prompt = os.environ["PROMPT"].encode()
assert prompt == directive + b"\nrole task\n| godspeed", prompt[:80]
PY

echo GATE_OAUTH_ROUTE_OK
