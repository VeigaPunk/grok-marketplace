#!/usr/bin/env bash
# Inject helper dry-run: hyprctl/wl-copy on PATH, no live paste.
set -euo pipefail

INTEG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INJ="$INTEG/bin/xbgst-surface-inject.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$INJ" ]] || fail "inject helper not executable: $INJ"
command -v hyprctl >/dev/null || fail "hyprctl missing"
command -v wl-copy >/dev/null || fail "wl-copy missing"

if grep -E -q 'claude|xask|spawn_subagent' "$INJ"; then
  fail "inject script must not mention claude/xask/spawn_subagent"
fi

out="$("$INJ" --dry-run /dev/null)" || fail "dry-run failed"
printf '%s\n' "$out" | grep -F -q -- 'hyprctl dispatch focuswindow class:grok-bot' || fail "dry-run missing focuswindow: $out"
printf '%s\n' "$out" | grep -F -q -- 'SHIFT, Insert' || fail "dry-run missing SHIFT+Insert: $out"
printf '%s\n' "$out" | grep -F -q -- 'CTRL, Return, activewindow' || fail "dry-run missing CTRL+Return: $out"
printf '%s\n' "$out" | grep -F -q -- 'wl-copy' || fail "dry-run missing wl-copy: $out"
if printf '%s\n' "$out" | grep -F -q -- 'grok -p'; then
  fail "inject must not exec grok -p: $out"
fi

nosub="$("$INJ" --dry-run --no-submit /dev/null)"
if printf '%s\n' "$nosub" | grep -F -q -- 'CTRL, Return, activewindow'; then
  fail "--no-submit still prints CTRL+Return: $nosub"
fi

echo "ok inject"
echo "$out"
