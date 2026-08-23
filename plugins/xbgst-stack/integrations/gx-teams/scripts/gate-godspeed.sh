#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
if [[ -n "${GX_TEAMS_GODSPEED_DIRECTIVE:-}" ]]; then
  CANON="$GX_TEAMS_GODSPEED_DIRECTIVE"
else
  CANON=""
  for cand in \
    "$ROOT/../../ssot/godspeed-core/directive.md" \
    "$ROOT/../grok-marketplace/plugins/xbgst-stack/ssot/godspeed-core/directive.md" \
    "${HOME}/.grok/ssot/godspeed-core/directive.md"
  do
    if [[ -f "$cand" ]]; then
      CANON="$cand"
      break
    fi
  done
fi
[[ -n "$CANON" ]] || { echo "gate-godspeed: canonical directive missing" >&2; exit 1; }
EXPECTED_SHA='db88963cbdf5a0db22b460b284bf6f1d1f4abac9eaadb28bdb5e9bffe27be3bb'
TMP_DIR=$(mktemp -d)
cleanup() { rm -rf -- "$TMP_DIR"; }
trap cleanup EXIT

[[ -f "$CANON" ]]
[[ $(sha256sum -- "$CANON" | awk '{print $1}') == "$EXPECTED_SHA" ]]

export HOME="$TMP_DIR/home"
export GX_TEAMS_STATE="$TMP_DIR/state"
export GX_TEAMS_GODSPEED_DIRECTIVE="$CANON"
export GX_TEAMS_SOURCE_ONLY=1
# shellcheck source=../gx-teams.sh
source "$GT"

resolved=$(resolve_godspeed_directive)
# Path string equality to sibling marketplace is not required; pin is sha256.
[[ $(sha256sum -- "$resolved" | awk '{print $1}') == "$EXPECTED_SHA" ]]
write_godspeed acp gx-labrat-acp
cmp -s -- "$resolved" "$GX_TEAMS_STATE/acp/godspeed/gx-labrat-acp.txt"

prompt=$(compose_godspeed_prompt $'handoff\n| godspeed\n| godspeed')
PROMPT="$prompt" python3 - "$resolved" <<'PY'
import os
import pathlib
import sys

directive = pathlib.Path(sys.argv[1]).read_bytes()
prompt = os.environ["PROMPT"].encode()
expected = directive + b"\nhandoff\n| godspeed"
assert prompt == expected
assert prompt.startswith(directive)
assert prompt.endswith(b"| godspeed")
assert prompt[len(directive):].count(b"| godspeed") == 1
PY
[[ $(compose_godspeed_prompt "$prompt") == "$prompt" ]]

# Global-array inject (compat).
argv=(env GROK_SUBAGENTS=0 /usr/bin/grok --no-leader -p $'role task\n| godspeed\n| godspeed')
inject_godspeed_into_grok_prompt argv
PROMPT="${argv[-1]}" python3 - "$resolved" <<'PY'
import os
import pathlib
import sys

directive = pathlib.Path(sys.argv[1]).read_bytes()
prompt = os.environ["PROMPT"].encode()
assert prompt == directive + b"\nrole task\n| godspeed"
PY

# Function-local nameref inject (mirrors cmd_spawn's local -a command_argv).
inject_local() {
  local -a command_argv=(env GROK_SUBAGENTS=0 /usr/bin/grok --no-leader -p $'local task\n| godspeed')
  inject_godspeed_into_grok_prompt command_argv
  PROMPT="${command_argv[-1]}" python3 - "$1" <<'PY'
import os
import pathlib
import sys

directive = pathlib.Path(sys.argv[1]).read_bytes()
prompt = os.environ["PROMPT"].encode()
assert prompt == directive + b"\nlocal task\n| godspeed"
PY
}
inject_local "$resolved"

python3 - "$ROOT/scripts/acp-live-dm.py" "$resolved" <<'PY'
import importlib.util
import pathlib
import sys

module_path = pathlib.Path(sys.argv[1])
directive = pathlib.Path(sys.argv[2]).read_bytes()
spec = importlib.util.spec_from_file_location("acp_live_dm", module_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

prompt = module.build_prompt("follow-up\n| godspeed\n| godspeed", include_rules=False).encode()
assert prompt == directive + b"\nfollow-up\n| godspeed"
assert prompt.startswith(directive)
assert prompt.endswith(b"| godspeed")
assert prompt[len(directive):].count(b"| godspeed") == 1
assert module.build_prompt(prompt.decode()).encode() == prompt
PY

# Optional walk after unset env: sibling marketplace / ssot must still pin.
unset GX_TEAMS_GODSPEED_DIRECTIVE
resolved_walk=$(resolve_godspeed_directive)
[[ $(sha256sum -- "$resolved_walk" | awk '{print $1}') == "$EXPECTED_SHA" ]]

echo GATE_GODSPEED_OK
