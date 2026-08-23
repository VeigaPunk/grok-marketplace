#!/usr/bin/env bash
# Mid-run PATH xask extract contract. Default: fixtures only (XASK_LIVE=0).
# Do not grep PONG on CLI envelope stdout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXTRACT="$ROOT/scripts/xask-spark-stdout.py"
FIX="$ROOT/tests/fixtures/xask-midrun"
SID="sp-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

fail() { echo "FAIL: $*" >&2; exit 1; }
need() { [[ -f "$1" ]] || fail "missing $1"; }

echo "→ test-xask-midrun-ping: $ROOT"

need "$EXTRACT"
need "$FIX/envelope.json"
need "$FIX/run/xbrd-spark/$SID/out/result.json"
chmod +x "$EXTRACT" 2>/dev/null || true

strip_pong() {
  # Exactly the model field: PONG plus its single trailing newline, no extra.
  python3 -c 'import sys; s=sys.stdin.read(); sys.exit(0 if s=="PONG\n" else 1)'
}

run_extract() {
  local envfile=$1
  XDG_RUNTIME_DIR="$FIX/run" python3 "$EXTRACT" <"$envfile"
}

# Do not capture into bash vars — command substitution strips trailing newlines.
run_extract "$FIX/envelope.json" | strip_pong || fail "clean envelope must extract exact PONG\\n"
leaked="$(run_extract "$FIX/envelope.json" | tr -d '\n')"
if printf '%s' "$leaked" | grep -E -q 'spark_id|content_hash|Godspeed-enabled|ping: return the single word PONG'; then
  fail "extract leaked envelope/prompt"
fi

run_extract "$FIX/envelope-prefixed.txt" | strip_pong || fail "usage_limit prefix must still extract exact PONG\\n"
if run_extract "$FIX/envelope-prefixed.txt" | grep -q usage_limit; then
  fail "extract leaked usage_limit banner"
fi

if XDG_RUNTIME_DIR="$FIX/run" python3 "$EXTRACT" <"$FIX/envelope-malformed.txt" >/tmp/xask-midrun-malformed.out 2>/tmp/xask-midrun-malformed.err; then
  fail "malformed envelope must not exit 0"
fi
if grep -q PONG /tmp/xask-midrun-malformed.out 2>/dev/null; then
  fail "malformed extract must not emit PONG"
fi

XDG_RUNTIME_DIR="$FIX/canary/run" python3 "$EXTRACT" <"$FIX/envelope.json" \
  | python3 -c 'import sys; s=sys.stdin.read(); sys.exit(0 if s=="XCANARY\n" else 1)' \
  || fail "source-follow: result.json stdout swap must follow (want XCANARY\\n)"
if XDG_RUNTIME_DIR="$FIX/canary/run" python3 "$EXTRACT" <"$FIX/envelope.json" | grep -q PONG; then
  fail "source-follow leaked prompt PONG"
fi

# sekhmet default_root: XBRD_SPARK_ROOT is the parent of <sid>/, and wins over XDG.
rootprobe=$(mktemp -d)
mkdir -p "$rootprobe/custom/$SID/out" "$rootprobe/xdg/xbrd-spark/$SID/out"
printf '%s\n' '{"status":"ok","stdout":"FROM_XBRD_SPARK_ROOT\n"}' >"$rootprobe/custom/$SID/out/result.json"
printf '%s\n' '{"status":"ok","stdout":"FROM_XDG\n"}' >"$rootprobe/xdg/xbrd-spark/$SID/out/result.json"
XBRD_SPARK_ROOT="$rootprobe/custom" XDG_RUNTIME_DIR="$rootprobe/xdg" python3 "$EXTRACT" <"$FIX/envelope.json" \
  | python3 -c 'import sys; s=sys.stdin.read(); sys.exit(0 if s=="FROM_XBRD_SPARK_ROOT\n" else 1)' \
  || fail "XBRD_SPARK_ROOT must win over XDG_RUNTIME_DIR"
rm -rf "$rootprobe"

# sekhmet validate_spark_id accepts non-hex remainder (sp-A_b-9)
idprobe=$(mktemp -d)
nsid="sp-A_b-9"
mkdir -p "$idprobe/xbrd-spark/$nsid/out"
printf '%s\n' '{"status":"ok","stdout":"NONHEX\n"}' >"$idprobe/xbrd-spark/$nsid/out/result.json"
printf '%s\n' "{\"spark_id\":\"$nsid\",\"status\":\"ok\",\"result_path\":\"/tmp/xbgst-sentinel-evil-result.json\"}" >"$idprobe/env.json"
XDG_RUNTIME_DIR="$idprobe" python3 "$EXTRACT" <"$idprobe/env.json" \
  | python3 -c 'import sys; s=sys.stdin.read(); sys.exit(0 if s=="NONHEX\n" else 1)' \
  || fail "sekhmet-valid non-hex spark_id must extract"
rm -rf "$idprobe"

# XDG unset → /tmp/xbrd-spark (not /run/user/UID)
miss=$(mktemp)
printf '%s\n' '{"spark_id":"sp-deadbeefcafebabe","status":"ok"}' >"$miss"
set +e
xdg_err=$(env -u XDG_RUNTIME_DIR -u XBRD_SPARK_ROOT python3 "$EXTRACT" <"$miss" 2>&1 >/dev/null)
xdg_rc=$?
set -e
rm -f "$miss"
[[ $xdg_rc -ne 0 ]] || fail "missing /tmp/xbrd-spark result must not exit 0"
printf '%s' "$xdg_err" | grep -q '/tmp/xbrd-spark/sp-deadbeefcafebabe' \
  || fail "XDG unset must look under /tmp/xbrd-spark; got $xdg_err"

# PATH survival: skill-snippet shaped (HOME isolated, parent-expanded PATH, bash -c not -lc)
tmp=$(mktemp -d)
XASK_PATH="${HOME}/.local/bin:/usr/bin:/bin"
if ! env -i HOME="$tmp" TMPDIR="$tmp" PATH="$XASK_PATH" bash -c 'command -v xask' >/dev/null; then
  fail "skill-snippet PATH must find xask"
fi
if env -i HOME="$tmp" TMPDIR="$tmp" PATH="/usr/bin:/bin" bash -c 'command -v xask' >/dev/null; then
  fail "PATH=/usr/bin:/bin must hide xask (contract still true)"
fi
rm -rf "$tmp"
# spawn protocol is fnm-always. env -i above is harness PATH-scrub only.
# sekhmet clap --root rejects empty XBRD_SPARK_ROOT — gx-teams unsets it unless --spark.
SKILL="$ROOT/skills/xbgst/SKILL.md"
grep -q 'Spawn protocol (fnm multishells always)' "$SKILL" \
  || fail "skill must name fnm-always spawn protocol"
if grep -E 'pure-bash-isolated|Fallback pure bash isolation|If fnm unavailable, fall back' "$SKILL" >/dev/null; then
  fail "skill must not document env -i spawn fallback"
fi
GX="$ROOT/integrations/gx-teams/gx-teams.sh"
if [[ -f "$GX" ]]; then
  grep -q 'unset XBRD_SPARK_ROOT' "$GX" \
    || fail "gx-teams must unset XBRD_SPARK_ROOT when pane is not spark"
  if grep -F 'XBRD_SPARK_ROOT="${XBRD_SPARK_ROOT:-}"' "$GX" >/dev/null; then
    fail "gx-teams must not export empty XBRD_SPARK_ROOT"
  fi
fi

if [[ "${XASK_LIVE:-0}" == "1" ]]; then
  live=$(mktemp)
  set +e
  xask --spark --gs --service-tier fast cdx 'ping: return the single word PONG and nothing else' >"$live" 2>/tmp/xask-midrun-live.err
  rc=$?
  set -e
  [[ $rc -eq 0 ]] || fail "live xask exit $rc"
  python3 "$EXTRACT" <"$live" | strip_pong || fail "live extract must strip to PONG\\n"
  rm -f "$live"
  echo "PASS: xask midrun ping (fixtures + live)"
else
  echo "PASS: xask midrun ping (fixtures; XASK_LIVE=0)"
fi
