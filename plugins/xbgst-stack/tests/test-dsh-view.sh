#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; VIEW="$ROOT/scripts/dsh-view.sh"
fail(){ echo "FAIL: $*" >&2; exit 1; }
[[ -x "$VIEW" ]] || fail viewer-executable

tmp="$(mktemp -d /tmp/xbgst-dsh-view.XXXXXX)"; trap 'rm -rf "$tmp"' EXIT
runs="$tmp/runs"; mkdir -p "$runs/run-a/sess-settled" "$runs/run-b/sess-failed"

# Fixture 1: settled session, terminal turn/end at seq 3 (will be OLDER).
cat >"$runs/run-a/sess-settled/session.jsonl" <<'EOF'
{"seq":1,"event":"turn/start","ts":"2026-08-22T10:00:00Z"}
{"seq":2,"event":"step/start"}
{"seq":2,"event":"tool/call","tool":"shell"}
{"seq":2,"event":"tool/result","ok":true}
{"seq":2,"event":"assistant/message","text":"done"}
{"seq":3,"event":"turn/end","status":"completed","error_category":"none"}
EOF

# Fixture 2: failed session, terminal turn/end at seq 7 with error_category=model
# (will be NEWEST). Carries an unmatched event name plus a schema-less line so the
# defensive fallback (observed keys surfaced, never guessed) is exercised.
cat >"$runs/run-b/sess-failed/session.jsonl" <<'EOF'
{"seq":1,"event":"turn/start","ts":"2026-08-22T11:00:00Z"}
{"seq":2,"event":"step/start"}
{"seq":2,"event":"tool/call","tool":"shell"}
{"seq":2,"event":"tool/result","ok":false}
{"seq":2,"event":"weird/thing","note":"unmatched event name"}
{"seq":2,"mystery":"no-event-key","payload":1}
{"seq":7,"event":"turn/end","status":"error","error_category":"model"}
EOF

touch -d '2026-08-22 10:00:00' "$runs/run-a/sess-settled/session.jsonl"
touch -d '2026-08-22 11:00:00' "$runs/run-b/sess-failed/session.jsonl"

sum_before="$(sha256sum "$runs/run-b/sess-failed/session.jsonl" | awk '{print $1}')"

# --- newest pick + failed-shaped render ---
o="$(bash "$VIEW" latest "$runs")"
echo "$o"
grep -qF '# supporting evidence only — mission ledger authoritative' <<<"$o" || fail banner
grep -q '^file: .*/run-b/sess-failed/session\.jsonl$' <<<"$o" || fail newest-picked
grep -q '^trace: sess-failed#7$' <<<"$o" || fail trace-format
grep -q '^status: failed$' <<<"$o" || fail status-failed
grep -q '^error_category: model$' <<<"$o" || fail ecat-failed
grep -qF 'events: turn/start=1 step/start=1 tool/call=1 tool/result=1 assistant/message=0 turn/end=1 other=keys(mystery+payload+seq),weird/thing' <<<"$o" || fail counts-line

# --- read-only guarantee: fixture bytes unchanged across a run ---
sum_after="$(sha256sum "$runs/run-b/sess-failed/session.jsonl" | awk '{print $1}')"
[[ "$sum_before" == "$sum_after" ]] || fail sha256-changed

# --- settled mapping (make fixture 1 newest, re-render) ---
touch -d '2026-08-22 12:00:00' "$runs/run-a/sess-settled/session.jsonl"
o2="$(bash "$VIEW" latest "$runs")"
echo "$o2"
grep -q '^trace: sess-settled#3$' <<<"$o2" || fail trace-settled
grep -q '^status: settled$' <<<"$o2" || fail status-settled
grep -q '^error_category: none$' <<<"$o2" || fail ecat-settled
grep -q '^file: .*/run-a/sess-settled/session\.jsonl$' <<<"$o2" || fail newest-settled

# --- (a) rc.8 nested-reason failure (F1): terminal turn/end carries
# data.reason.kind="error" + data.reason.error.code; no top-level status/ecat.
mkdir -p "$runs/run-c/sess-nested"
cat >"$runs/run-c/sess-nested/session.jsonl" <<'EOF'
{"type":"turn/start","seq":1,"time":1787376729000,"data":{"turn":1}}
{"type":"step/start","seq":2,"time":1787376729000,"data":{"turn":1,"step":1}}
{"type":"step/end","seq":14,"time":1787376732574,"data":{"turn":1,"step":1}}
{"event":"turn/end","seq":15,"data":{"reason":{"kind":"error","error":{"code":"MISSING_CREDENTIAL"}}}}
EOF
touch -d '2026-08-22 13:00:00' "$runs/run-c/sess-nested/session.jsonl"
o3="$(bash "$VIEW" latest "$runs")"
echo "$o3"
grep -q '^trace: sess-nested#15$' <<<"$o3" || fail trace-nested
grep -q '^status: failed$' <<<"$o3" || fail status-nested-failed
grep -q '^error_category: .*MISSING_CREDENTIAL' <<<"$o3" || fail ecat-nested
grep -q '^file: .*/run-c/sess-nested/session\.jsonl$' <<<"$o3" || fail newest-nested

# --- (b) rc.8 .zstd containers (F2): newest file under the root is .zstd-only;
# viewer must skip it entirely and pick the older PLAIN *.jsonl.
mkdir -p "$runs/run-d/sess-zstd"
printf 'not-a-real-zstd-container' >"$runs/run-d/sess-zstd/session.jsonl.zstd"
touch -d '2026-08-22 14:00:00' "$runs/run-d/sess-zstd/session.jsonl.zstd"
o4="$(bash "$VIEW" latest "$runs")"
echo "$o4"
grep -q '^file: .*/run-c/sess-nested/session\.jsonl$' <<<"$o4" || fail zstd-skip
grep -q '^status: failed$' <<<"$o4" || fail zstd-skip-status

# --- turn/end-only log without reason shape or top-level status: unknown +
# stderr warn line (dsh-events.md rule 2 — absence of category is a bridge bug).
mkdir -p "$runs/run-e/sess-shapeless"
cat >"$runs/run-e/sess-shapeless/session.jsonl" <<'EOF'
{"seq":1,"event":"turn/start"}
{"seq":9,"event":"turn/end"}
EOF
touch -d '2026-08-22 15:00:00' "$runs/run-e/sess-shapeless/session.jsonl"
set +e; o5="$(bash "$VIEW" latest "$runs" 2>"$tmp/warn.err")"; r=$?; set -e
[[ $r -eq 0 ]] || fail "shapeless rc=$r"
grep -q '^status: unknown$' <<<"$o5" || fail status-shapeless
grep -qx 'warn: terminal event without reason shape' "$tmp/warn.err" || fail warn-shapeless

# --- exit-2 sentinels ---
set +e; o=$(bash "$VIEW" latest "$tmp/no-such-root" 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_VIEW_BLOCKED_NO_ROOT <<<"$o" || fail "no-root sentinel: rc=$r $o"

mkdir -p "$tmp/empty-root"
set +e; o=$(bash "$VIEW" latest "$tmp/empty-root" 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_VIEW_BLOCKED_EMPTY <<<"$o" || fail "empty sentinel: rc=$r $o"

echo 'PASS: dsh-view read-only render'
