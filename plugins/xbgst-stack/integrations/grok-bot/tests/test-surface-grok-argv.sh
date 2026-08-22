#!/usr/bin/env bash
# M02 dry-run argv: grok + (-p|--single) + --cwd + xbgst. No exec.
# Token after -p/--single must be the /xbgst prompt, never --verbatim.
set -euo pipefail

INTEG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="$INTEG/bin/xbgst-surface-run.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$RUN" ]] || fail "run helper not executable: $RUN"

out="$(env -u XBGST_SURFACE_EXEC "$RUN" --print hello)"
[[ -n "$out" ]] || fail "empty argv"

printf '%s\n' "$out" | grep -F -q -- 'grok' || fail "argv missing grok: $out"
if ! printf '%s\n' "$out" | grep -E -q -- '(^|[[:space:]])-p([[:space:]]|$)|(^|[[:space:]])--single([[:space:]]|$)'; then
  fail "argv missing -p or --single: $out"
fi
printf '%s\n' "$out" | grep -F -q -- '--cwd' || fail "argv missing --cwd: $out"
printf '%s\n' "$out" | grep -F -q -- 'xbgst' || fail "argv missing xbgst: $out"
printf '%s\n' "$out" | grep -F -q -- '--verbatim' || fail "argv missing --verbatim: $out"
if printf '%s\n' "$out" | grep -F -q -- '--no-subagents'; then
  fail "argv must not contain --no-subagents: $out"
fi

read -r -a argv <<< "$out"
found_p=0
for i in "${!argv[@]}"; do
  tok="${argv[$i]}"
  if [[ "$tok" == "-p" || "$tok" == "--single" ]]; then
    found_p=1
    next_i=$((i + 1))
    [[ $next_i -lt ${#argv[@]} ]] || fail "missing prompt after $tok: $out"
    next="${argv[$next_i]}"
    [[ "$next" != "--verbatim" ]] || fail "token after $tok is --verbatim (prompt required): $out"
    [[ "$next" == /xbgst* ]] || fail "token after $tok must start with /xbgst (got $next): $out"
  fi
done
[[ "$found_p" -eq 1 ]] || fail "no -p/--single token after split: $out"

echo "ok argv"
echo "$out"
