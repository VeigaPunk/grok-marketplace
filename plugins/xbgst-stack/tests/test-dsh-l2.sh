#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; WRAP="$ROOT/scripts/dsh-l2.sh"
fail(){ echo "FAIL: $*" >&2; exit 1; }
[[ -x "$WRAP" ]] || fail wrapper
fake="$(mktemp -d /tmp/xbgst-dsh-test.XXXXXX)"; trap 'rm -rf "$fake"' EXIT
cat >"$fake/fnm" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == env ]] && echo 'export FNM_TEST=1'
EOF
chmod +x "$fake/fnm"
cat >"$fake/dsh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" | grep -qx -- --dump-config || exit 9
echo DSH_FAKE_PASS
EOF
chmod +x "$fake/dsh"
tmp="$(mktemp -d /tmp/xbgst-dsh-run.XXXXXX)"; trap 'rm -rf "$fake" "$tmp"' EXIT
set +e
o=$(cd "$ROOT" && PATH="$fake:$PATH" env -u DSH_BIN bash "$WRAP" --profile xbgst-worker --dump-config 2>&1); r=$?
set -e
[[ $r -eq 2 ]] && grep -q DSH_TICK_BLOCKED_CWD <<<"$o" || fail cwd
for spec in '--profile nope' '--profile=nope' '-p general-purpose' '-p explore' '/login'; do
  set +e; o=$(cd "$tmp" && PATH="$fake:$PATH" DSH_BIN="$fake/dsh" bash "$WRAP" --profile xbgst-worker $spec 2>&1); r=$?; set -e
  [[ $r -eq 2 ]] || fail "$spec rc"; case "$spec" in *profile*) grep -q DSH_TICK_BLOCKED_PROFILE <<<"$o";; *general*|*explore*) grep -q DSH_TICK_BLOCKED_BANNED_TYPE <<<"$o";; /login) grep -q DSH_TICK_BLOCKED_LOGIN <<<"$o";; esac || fail "$spec sentinel"
done
o=$(cd "$tmp" && PATH="$fake:$PATH" DSH_BIN="$fake/dsh" bash "$WRAP" --profile xbgst-worker --dump-config 2>&1); grep -q DSH_FAKE_PASS <<<"$o" || fail pass

# NO_BIN: fallback path misses when HOME has no cached install and DSH_BIN unset.
mkdir -p "$tmp/nohome"
set +e; o=$(cd "$tmp" && PATH="$fake:$PATH" env -u DSH_BIN HOME="$tmp/nohome" bash "$WRAP" --profile xbgst-worker --dump-config 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_TICK_BLOCKED_NO_BIN <<<"$o" || fail "no-bin rc/sentinel: $o"

# NO_FNM: PATH scrubbed of fnm -> refuse before anything else.
bare="$(mktemp -d /tmp/xbgst-dsh-bare.XXXXXX)"; trap 'rm -rf "$fake" "$tmp" "$bare"' EXIT
cp "$fake/dsh" "$bare/dsh"
set +e; o=$(cd "$tmp" && /usr/bin/env -i PATH="$bare" "$(command -v bash)" "$WRAP" --profile xbgst-worker --dump-config 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_TICK_BLOCKED_NO_FNM <<<"$o" || fail "no-fnm rc/sentinel: $o"

# Pass-through against the REAL pinned binary (offline): --dump-config only,
# seeded hardened profile must show patched (disabled) plugins.
REAL_DSH="$HOME/.cache/xbgst-dsh/smoke.aWXt/node_modules/.bin/dsh"
if [[ -x "$REAL_DSH" ]]; then
  set +e
  o=$(cd "$tmp" && PATH="$fake:$PATH" env -u DSH_BIN DSH_TIMEOUT_SECS=60 bash "$WRAP" --profile xbgst-worker --dump-config 2>&1); r=$?
  set -e
  [[ $r -eq 0 ]] || fail "real dsh --dump-config rc=$r: $o"
  grep -q 'disabled: true' <<<"$o" || fail "hardened patch not applied in dump: $o"
fi

# F6 runs-prefix allowlist (r1 §1): XBGST_DSH_HOME must resolve under DSH_RUNS_ROOT.
# Block: console-home -> rc2 + token.
set +e; o=$(cd "$tmp" && PATH="$fake:$PATH" DSH_BIN="$fake/dsh" XBGST_DSH_HOME=/home/vgpnk/.cache/xbgst-dsh/console-home bash "$WRAP" --profile xbgst-worker --dump-config 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_TICK_BLOCKED_XBGST_HOME <<<"$o" || fail "xbgst-home console-home rc/sentinel: $o"
# Block: $HOME/.dsh -> rc2.
set +e; o=$(cd "$tmp" && PATH="$fake:$PATH" DSH_BIN="$fake/dsh" XBGST_DSH_HOME="$HOME/.dsh" bash "$WRAP" --profile xbgst-worker --dump-config 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_TICK_BLOCKED_XBGST_HOME <<<"$o" || fail "xbgst-home ~/.dsh rc/sentinel: $o"
# Pass: DSH_RUNS_ROOT override + XBGST_DSH_HOME beneath it -> fake-bin pass-through.
RUNS_ROOT="$(mktemp -d /tmp/xbgst-dsh-runs.XXXXXX)"; trap 'rm -rf "$fake" "$tmp" "$bare" "$RUNS_ROOT"' EXIT
set +e; o=$(cd "$tmp" && PATH="$fake:$PATH" DSH_BIN="$fake/dsh" DSH_RUNS_ROOT="$RUNS_ROOT" XBGST_DSH_HOME="$RUNS_ROOT/run-1" bash "$WRAP" --profile xbgst-worker --dump-config 2>&1); r=$?; set -e
[[ $r -eq 0 ]] && grep -q DSH_FAKE_PASS <<<"$o" || fail "xbgst-home runs-root pass rc=$r: $o"

# Timeout: TERM the process group when DSH_TIMEOUT_SECS elapses (stub hangs).
cat >"$fake/slow" <<'EOF'
#!/usr/bin/env bash
[[ "$(basename "$0")" == dsh ]] || exit 9
sleep 30
EOF
mv "$fake/slow" "$fake/dsh_slow" 2>/dev/null || true
mkdir -p "$fake/bin"; cp "$fake/dsh_slow" "$fake/bin/dsh" && chmod +x "$fake/bin/dsh"
t0=$SECONDS
set +e; o=$(cd "$tmp" && PATH="$fake:$PATH" DSH_BIN="$fake/bin/dsh" DSH_TIMEOUT_SECS=1 bash "$WRAP" --profile xbgst-worker --dump-config 2>&1); r=$?; set -e
dt=$((SECONDS - t0))
[[ $r -ne 0 && $dt -le 5 ]] || fail "timeout kill failed rc=$r dt=${dt}s"

# F4 argv-order (rc.8 commander rejects post-operand flags): fake bin captures the
# full spawned argv; --profile and the assembled --patch must BOTH precede the
# positional task operand in argv order.
cat >"$fake/dsh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$DSH_ARGV_CAPTURE"
EOF
chmod +x "$fake/dsh"
cap="$tmp/argv-capture.txt"
o=$(cd "$tmp" && PATH="$fake:$PATH" DSH_BIN="$fake/dsh" DSH_ARGV_CAPTURE="$cap" bash "$WRAP" --profile xbgst-worker 'Reply with exactly: XBGST_DSH_VIS_OK' 2>&1)
[[ -s "$cap" ]] || fail "argv capture empty: $o"
grep -qx -- '--profile' "$cap" || fail "argv missing --profile: $(cat "$cap")"
grep -qx -- '--patch' "$cap" || fail "argv missing --patch: $(cat "$cap")"
ln_task=$(grep -nxF -- 'Reply with exactly: XBGST_DSH_VIS_OK' "$cap" | cut -d: -f1)
ln_prof=$(grep -nx -- '--profile' "$cap" | head -1 | cut -d: -f1)
ln_patch=$(grep -nx -- '--patch' "$cap" | head -1 | cut -d: -f1)
[[ -n "$ln_task" && -n "$ln_prof" && -n "$ln_patch" ]] || fail "argv lines unresolved: $(cat "$cap")"
(( ln_prof < ln_task && ln_patch < ln_task )) || fail "argv order: flags must precede operand (profile@$ln_prof patch@$ln_patch task@$ln_task)"

echo 'PASS: dsh-l2 fail-closed + pass-through'