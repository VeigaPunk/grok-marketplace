#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; WRAP="$ROOT/scripts/dsh-web.sh"
fail(){ echo "FAIL: $*" >&2; exit 1; }
[[ -x "$WRAP" ]] || fail wrapper
fake="$(mktemp -d /tmp/xbgst-dsh-web-test.XXXXXX)"; tmp="$(mktemp -d /tmp/xbgst-dsh-web-run.XXXXXX)"; bare="$(mktemp -d /tmp/xbgst-dsh-web-bare.XXXXXX)"
SLEEP_PID=""; PY_PID=""
trap 'rm -rf "$fake" "$tmp" "$bare"; for p in $SLEEP_PID $PY_PID; do [[ -n "$p" ]] && kill "$p" 2>/dev/null || true; done' EXIT
cat >"$fake/fnm" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == env ]] && echo 'export FNM_TEST=1'
EOF
chmod +x "$fake/fnm"
cat >"$fake/dsh" <<'EOF'
#!/usr/bin/env bash
exit 9
EOF
chmod +x "$fake/dsh"
port_busy(){ if (exec 3<>/dev/tcp/127.0.0.1/8787) 2>/dev/null; then exec 3>&- 3<&-; return 0; fi; return 1; }

# Test-only pin hatch: every fake-bin case drives the wrapper off a synthetic pin.env
# via XBGST_PIN_ENV so the real manifest is never touched.
mkpin() { # mkpin <path> <console-home> [port]
  { printf 'DSH_CONSOLE_HOME=%s\n' "$2"; printf 'DSH_CONSOLE_PORT=%s\n' "${3:-8787}"; } >"$1"
}
PIN="$tmp/pin.env"
mkdir -p "$tmp/home"
mkpin "$PIN" "$tmp/home"

# HOST / PORT: wrapper owns all flags; any operator attempt is refused (fake bin).
for spec in '--host 0.0.0.0' '--host=0.0.0.0' '--port 9999' '--port=9999'; do
  set +e; o=$(PATH="$fake:$PATH" DSH_BIN="$fake/dsh" XBGST_PIN_ENV="$PIN" bash "$WRAP" up $spec 2>&1); r=$?; set -e
  [[ $r -eq 2 ]] || fail "$spec rc=$r: $o"
  case "$spec" in *host*) tok=DSH_WEB_BLOCKED_HOST;; *port*) tok=DSH_WEB_BLOCKED_PORT;; esac
  grep -q "$tok" <<<"$o" || fail "$spec sentinel: $o"
done

# NO_BIN: fallback path misses when HOME has no cached install and DSH_BIN unset.
mkdir -p "$tmp/nohome"
set +e; o=$(PATH="$fake:$PATH" env -u DSH_BIN HOME="$tmp/nohome" XBGST_PIN_ENV="$PIN" bash "$WRAP" up 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_WEB_BLOCKED_NO_BIN <<<"$o" || fail "no-bin rc/sentinel: $o"

# NO_FNM: PATH scrubbed of fnm -> refuse before anything else.
set +e; o=$(/usr/bin/env -i PATH="$bare" "$(command -v bash)" "$WRAP" up 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_WEB_BLOCKED_NO_FNM <<<"$o" || fail "no-fnm rc/sentinel: $o"

# BAD_PIN: pin.env with DSH_CONSOLE_HOME unset -> refuse.
mkpin "$tmp/pin-empty.env" ""
set +e; o=$(PATH="$fake:$PATH" DSH_BIN="$fake/dsh" XBGST_PIN_ENV="$tmp/pin-empty.env" bash "$WRAP" up 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_WEB_BLOCKED_BAD_PIN <<<"$o" || fail "bad-pin-unset rc/sentinel: $o"
# BAD_PIN: pin.env console-home resolves to $HOME/.dsh -> refuse (resolved-path compare, incl. symlink).
mkdir -p "$tmp/h2/.dsh"; ln -s .dsh "$tmp/h2/link"
for home in "$tmp/h2/.dsh" "$tmp/h2/link"; do
  mkpin "$tmp/pin-poison.env" "$home"
  set +e; o=$(PATH="$fake:$PATH" DSH_BIN="$fake/dsh" HOME="$tmp/h2" XBGST_PIN_ENV="$tmp/pin-poison.env" bash "$WRAP" up 2>&1); r=$?; set -e
  [[ $r -eq 2 ]] && grep -q DSH_WEB_BLOCKED_BAD_PIN <<<"$o" || fail "bad-pin $home rc/sentinel: $o"
done

# SSoT: caller-supplied DSH_HOME is IGNORED outright — poisoned caller DSH_HOME with a
# clean pin must NOT trip the pin guard, and state lands under the pin's console-home.
set +e; o=$(PATH="$fake:$PATH" DSH_BIN="$fake/dsh" HOME="$tmp/h2" DSH_HOME="$tmp/h2/.dsh" XBGST_PIN_ENV="$PIN" bash "$WRAP" up 2>&1); r=$?; set -e
[[ $r -eq 2 ]] || fail "caller-DSH_HOME-ignored rc=$r: $o"
grep -q DSH_WEB_BLOCKED_BAD_PIN <<<"$o" && fail "caller DSH_HOME leaked into guard: $o" || true
[[ -f "$tmp/home/web.log" ]] || fail "pin console-home not used as DSH_HOME (no web.log): $o"
rm -f "$tmp/home/web.log" "$tmp/home/web.pid"

# BUSY: concurrent-up lock (live foreign PID in the PID file).
mkdir -p "$tmp/home3"; mkpin "$tmp/pin3.env" "$tmp/home3"
sleep 60 & SLEEP_PID=$!
echo "$SLEEP_PID" >"$tmp/home3/web.pid"
set +e; o=$(PATH="$fake:$PATH" DSH_BIN="$fake/dsh" XBGST_PIN_ENV="$tmp/pin3.env" bash "$WRAP" up 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_WEB_BLOCKED_BUSY <<<"$o" || fail "busy-lock rc/sentinel: $o"
kill "$SLEEP_PID" 2>/dev/null || true; wait "$SLEEP_PID" 2>/dev/null || true; SLEEP_PID=""

# BUSY: stale PID file -> purge for the next invocation, still refuse this one.
mkdir -p "$tmp/home5"; mkpin "$tmp/pin5.env" "$tmp/home5"
echo 999999 >"$tmp/home5/web.pid"
set +e; o=$(PATH="$fake:$PATH" DSH_BIN="$fake/dsh" XBGST_PIN_ENV="$tmp/pin5.env" bash "$WRAP" up 2>&1); r=$?; set -e
[[ $r -eq 2 ]] && grep -q DSH_WEB_BLOCKED_BUSY <<<"$o" || fail "busy-stale rc/sentinel: $o"
[[ ! -e "$tmp/home5/web.pid" ]] || fail "stale pidfile not purged"

# BUSY: port already bound by a foreign process.
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$tmp/home4"; mkpin "$tmp/pin4.env" "$tmp/home4"
  python3 -m http.server 8787 --bind 127.0.0.1 >/dev/null 2>&1 & PY_PID=$!
  for _ in $(seq 1 20); do if port_busy; then break; fi; sleep 0.2; done
  port_busy || fail "python3 probe server did not bind 8787"
  set +e; o=$(PATH="$fake:$PATH" DSH_BIN="$fake/dsh" XBGST_PIN_ENV="$tmp/pin4.env" bash "$WRAP" up 2>&1); r=$?; set -e
  kill "$PY_PID" 2>/dev/null || true; wait "$PY_PID" 2>/dev/null || true; PY_PID=""
  [[ $r -eq 2 ]] && grep -q DSH_WEB_BLOCKED_BUSY <<<"$o" || fail "busy-port rc/sentinel: $o"
  [[ ! -e "$tmp/home4/web.pid" ]] || fail "pidfile not released after busy-port refusal"
else
  echo "SKIP: python3 absent — busy-port block"
fi

# ONE real cycle against the pinned binary + console-home (canonical invocation,
# pin.env SSoT; caller DSH_HOME poisoned on purpose to prove it is ignored).
REAL_DSH="$HOME/.cache/xbgst-dsh/smoke.aWXt/node_modules/.bin/dsh"
CONSOLE_HOME=/home/vgpnk/.cache/xbgst-dsh/console-home
if [[ -x "$REAL_DSH" ]] && command -v fnm >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  port_busy && fail "port 8787 busy before real cycle" || true
  marker="$(mktemp /tmp/xbgst-dsh-web-marker.XXXXXX)"
  DSH_HOME="$tmp/h2/.dsh" bash "$WRAP" up || fail "real up"
  for _ in $(seq 1 30); do if curl -fsS -o /dev/null http://127.0.0.1:8787/ 2>/dev/null; then break; fi; sleep 0.5; done
  curl -fsS -o /dev/null http://127.0.0.1:8787/ || fail "no HTTP 200 after up"
  o=$(bash "$WRAP" status) || fail "real status rc"
  grep -q ok <<<"$o" || fail "real status print: $o"
  bash "$WRAP" down || fail "real down"
  if port_busy; then fail "port 8787 still bound after down"; fi
  # Teardown proof: real ~/.dsh untouched by the whole cycle.
  if [[ -d "$HOME/.dsh" ]]; then
    changed="$(find "$HOME/.dsh" -newer "$marker" -print -quit)"
    [[ -z "$changed" ]] || fail "~/.dsh mutated: $changed"
  else
    echo "SKIP: ~/.dsh absent — untouched-check"
  fi
  rm -f "$marker"
else
  echo "SKIP: real dsh cycle (missing bin/fnm/curl)"
fi

echo 'PASS: dsh-web loopback + fail-closed'
