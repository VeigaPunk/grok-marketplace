#!/usr/bin/env bash
# Wire xbgst-stack + livepatch on this host (idempotent).
# REPLACE_BIN is opt-in: export GROK_LIVEPATCH_REPLACE_BIN=1 before install-timer
# only if you want the 6h unit to replace ~/.grok/bin/grok.
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
  # Prefer canonical unit install (no REPLACE_BIN by default; units use @ROOT@)
  bash "$LP/scripts/install-timer.sh"
  # If caller opted into REPLACE_BIN, append env to the installed unit once
  if [[ "${GROK_LIVEPATCH_REPLACE_BIN:-}" == "1" ]]; then
    UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/grok-build-livepatch.service"
    if [[ -f "$UNIT" ]] && ! grep -q 'GROK_LIVEPATCH_REPLACE_BIN=1' "$UNIT"; then
      # Insert after [Service]
      sed -i '/^\[Service\]/a Environment=GROK_LIVEPATCH_REPLACE_BIN=1' "$UNIT"
      systemctl --user daemon-reload
      echo "✓ REPLACE_BIN enabled on timer unit (opt-in)"
    fi
  else
    echo "  tip: timer does not replace ~/.grok/bin/grok (set GROK_LIVEPATCH_REPLACE_BIN=1 to opt in)"
  fi
  echo "✓ livepatch timer enabled (root=$LP)"
  echo "  apply now: GROK_LIVEPATCH_FORCE=1 bash $LP/scripts/check-and-patch.sh"
  echo "  replace bin: GROK_LIVEPATCH_FORCE=1 GROK_LIVEPATCH_REPLACE_BIN=1 bash $LP/scripts/check-and-patch.sh"
else
  echo "⚠ livepatch/ missing under stack"
fi

echo "✓ xbgst-stack host install complete"
