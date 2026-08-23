#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Wrong flag order must clap-reject (flags belong before stdio).
if grok agent stdio --no-leader </dev/null >/dev/null 2>&1; then
  echo "FAIL: stdio --no-leader should clap-reject" >&2
  exit 1
fi
export GROK_SUBAGENTS=0
set +e
timeout 30s python3 "$ROOT/scripts/acp-oneshot.py" >/tmp/gx-acp-oneshot.out 2>/tmp/gx-acp-oneshot.err
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "Status: blocked E-acp (timeout or init fail, rc=$rc)" >&2
  cat /tmp/gx-acp-oneshot.err >&2 || true
  exit 2
fi
grep -q protocolVersion /tmp/gx-acp-oneshot.out
echo GATE_M07_OK
