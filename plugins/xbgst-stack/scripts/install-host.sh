#!/usr/bin/env bash
# Wire xbgst-stack + livepatch on this host (idempotent).
set -euo pipefail
STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LP="$STACK_ROOT/livepatch"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"

echo "→ xbgst-stack root: $STACK_ROOT"

mkdir -p "$GROK_HOME/agents" "$GROK_HOME/skills" "$GROK_HOME/commands"
if [[ -d "$STACK_ROOT/agents" ]]; then
  cp -a "$STACK_ROOT/agents/"*.md "$GROK_HOME/agents/" 2>/dev/null || true
  echo "✓ agents → $GROK_HOME/agents"
fi
if [[ -d "$STACK_ROOT/skills" ]]; then
  for d in "$STACK_ROOT/skills"/*; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    rm -rf "$GROK_HOME/skills/$name"
    cp -a "$d" "$GROK_HOME/skills/$name"
  done
  echo "✓ skills → $GROK_HOME/skills"
fi
if [[ -d "$STACK_ROOT/commands" ]]; then
  cp -a "$STACK_ROOT/commands/"*.md "$GROK_HOME/commands/" 2>/dev/null || true
  if [[ -d "$STACK_ROOT/commands/references" ]]; then
    mkdir -p "$GROK_HOME/commands/references"
    cp -a "$STACK_ROOT/commands/references/"* "$GROK_HOME/commands/references/" 2>/dev/null || true
  fi
  echo "✓ commands → $GROK_HOME/commands"
fi

if [[ -d "$LP/scripts" ]]; then
  chmod +x "$LP/scripts/"*.sh
  UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$UNIT_DIR"
  cat > "$UNIT_DIR/grok-build-livepatch.service" <<UNIT
[Unit]
Description=Grok Build livepatch (xbgst-stack bundled)
After=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$LP
Environment=GROK_LIVEPATCH_REPLACE_BIN=1
ExecStart=$LP/scripts/check-and-patch.sh
Nice=10

[Install]
WantedBy=default.target
UNIT
  cp -f "$LP/systemd/grok-build-livepatch.timer" "$UNIT_DIR/"
  systemctl --user daemon-reload
  systemctl --user enable --now grok-build-livepatch.timer 2>/dev/null || true
  echo "✓ livepatch timer enabled (root=$LP)"
  echo "  apply now: GROK_LIVEPATCH_FORCE=1 GROK_LIVEPATCH_REPLACE_BIN=1 bash $LP/scripts/check-and-patch.sh"
else
  echo "⚠ livepatch/ missing under stack"
fi

echo "✓ xbgst-stack host install complete"
