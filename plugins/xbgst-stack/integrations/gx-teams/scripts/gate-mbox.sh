#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GT="$ROOT/gx-teams.sh"
cd "$ROOT"

cargo test -q --manifest-path mailbox/Cargo.toml

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
python3 - <<'PY'
import os, pathlib
scratch = pathlib.Path(os.environ.get("XBGST_MAIL_ROOT", "/tmp/xbgst-mail"))
xdg = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000"))
assert not str(scratch.resolve()).startswith(str(xdg.resolve()) + os.sep) and scratch.resolve() != xdg.resolve()
assert str(scratch).startswith("/tmp") or "XBGST_MAIL_ROOT" in os.environ
print("scratch_ok", scratch)
PY

cleanup() { "$GT" nuke --team mboxgate >/dev/null 2>&1 || true; }
trap cleanup EXIT
if tmux has-session -t '=gx-teams-mboxgate' 2>/dev/null; then "$GT" nuke --team mboxgate; fi
"$GT" spawn --team mboxgate --name gx-labrat-mbox -- cmd true
cfg="$HOME/.gx-teams/mboxgate/config.json"
if [[ -n "${GX_TEAMS_STATE:-}" ]]; then
  cfg="${GX_TEAMS_STATE}/mboxgate/config.json"
fi
td=$(python3 - "$cfg" <<'PY'
import json,sys,os
cfg=json.load(open(sys.argv[1]))
td=cfg["panes"]["gx-labrat-mbox"]["tmpdir"]
assert td.startswith("/tmp/xbgst-gx-mboxgate-gx-labrat-mbox-"), td
assert not td.endswith("/")
xdg=os.environ.get("XDG_RUNTIME_DIR","/run/user/1000")
assert not td.startswith(xdg)
print(td)
PY
)
pid=$(jq -r '.panes["gx-labrat-mbox"].pane_pid' "$cfg")
tr '\0' '\n' < /proc/"$pid"/environ | grep -qx "XBGST_MAIL_ROOT=${td}/mail"
if tr '\0' '\n' < /proc/"$pid"/environ | grep -q '^XBRD_SPARK_ROOT='; then
  echo 'FAIL: spark root set without --spark argv' >&2
  exit 1
fi
test -d "${td}/mail"
test ! -e "${td}/spark"
"$GT" spawn --team mboxgate --name gx-labrat-spark -- cmd true --spark
spark_cfg="$cfg"
spark_td=$(python3 - "$spark_cfg" <<'PY'
import json,sys
cfg=json.load(open(sys.argv[1]))
td=cfg["panes"]["gx-labrat-spark"]["tmpdir"]
assert td.startswith("/tmp/xbgst-gx-mboxgate-gx-labrat-spark-"), td
print(td)
PY
)
spark_pid=$(jq -r '.panes["gx-labrat-spark"].pane_pid' "$spark_cfg")
tr '\0' '\n' < /proc/"$spark_pid"/environ | grep -qx "XBRD_SPARK_ROOT=${spark_td}/spark"
test -d "${spark_td}/spark"
inbox_dir="${GX_TEAMS_STATE:-$HOME/.gx-teams}/mboxgate/inboxes"
"$GT" dm --team mboxgate --to gx-labrat-mbox --text hi
inbox="$inbox_dir/gx-labrat-mbox.jsonl"
python3 - "$inbox" <<'PY'
import json,sys
last=open(sys.argv[1]).read().splitlines()[-1]
obj=json.loads(last)
assert obj["text"]=="hi" and obj["to"]=="gx-labrat-mbox" and obj["type"]=="dm"
print("last_line_ok")
PY
decoy=$(mktemp -d -- "/tmp/xbgst-gx-mboxgate-sentinel-XXXXXX")
"$GT" nuke --team mboxgate
test -d "$decoy"
rmdir -- "$decoy"
echo GATE_MBOX_OK
