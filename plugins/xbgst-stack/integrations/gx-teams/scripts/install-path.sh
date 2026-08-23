#!/usr/bin/env bash
# PATH overlay for gx-teams + xbgst-mailbox. Fail closed without fnm.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${XBGST_BIN_DIR:-$HOME/.local/bin}"

if ! command -v fnm >/dev/null 2>&1; then
  echo "BLOCKED: fnm missing" >&2
  exit 1
fi

mkdir -p "$BIN"
if command -v cargo >/dev/null 2>&1; then
  cargo build --release --manifest-path "$ROOT/mailbox/Cargo.toml"
  ln -sfn "$ROOT/mailbox/target/release/xbgst-mailbox" "$BIN/xbgst-mailbox"
elif [[ -x "$ROOT/mailbox/target/release/xbgst-mailbox" ]]; then
  ln -sfn "$ROOT/mailbox/target/release/xbgst-mailbox" "$BIN/xbgst-mailbox"
elif [[ -x "$ROOT/mailbox/target/debug/xbgst-mailbox" ]]; then
  ln -sfn "$ROOT/mailbox/target/debug/xbgst-mailbox" "$BIN/xbgst-mailbox"
else
  echo "BLOCKED: cargo missing and no xbgst-mailbox ELF" >&2
  exit 1
fi
chmod +x "$ROOT/gx-teams.sh"
ln -sfn "$ROOT/gx-teams.sh" "$BIN/gx-teams"
echo "linked $BIN/xbgst-mailbox"
echo "linked $BIN/gx-teams"
