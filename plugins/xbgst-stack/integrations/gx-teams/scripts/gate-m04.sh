#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
STATE="${GX_TEAMS_STATE:-$HOME/.gx-teams}"
cleanup() { "$GT" nuke --team mail >/dev/null 2>&1 || true; }
trap cleanup EXIT
if tmux has-session -t '=gx-teams-mail' 2>/dev/null; then "$GT" nuke --team mail; fi
"$GT" spawn --team mail --name gx-labrat-ping -- cmd true
test -d "$STATE/mail/inboxes"
sent=$("$GT" dm --team mail --to gx-labrat-ping --text hi)
grep -q 'sent' <<<"$sent"
inbox="$STATE/mail/inboxes/gx-labrat-ping.jsonl"
test -f "$inbox"
# refuse JSON array
python3 - "$inbox" <<'PY'
import json,sys
p=sys.argv[1]
raw=open(p).read().strip()
assert raw, "empty inbox"
# whole file must not parse as a JSON array
try:
    v=json.loads(raw)
    assert not isinstance(v, list), "JSON array forbidden (want JSONL)"
except json.JSONDecodeError:
    pass
last=raw.splitlines()[-1]
obj=json.loads(last)
assert obj.get("text")=="hi" and obj.get("to")=="gx-labrat-ping" and obj.get("type")=="dm"
PY
# missing dir → non-zero
rm -rf "$STATE/nosuch"
set +e
"$GT" dm --team nosuch --to gx-labrat-ping --text hi >/dev/null 2>&1
rc=$?
set -e
[[ $rc -ne 0 ]]
# dm must not mkdir a never-spawned team
[[ ! -e "$STATE/nosuch" ]]
"$GT" nuke --team mail
echo GATE_M04_OK
