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
  # Timer root resolution:
  #   GROK_LIVEPATCH_ROOT explicit → KEEP_STAMP=1 → Projects/grok-build-livepatch if present
  #   → else this stack's livepatch (unless GROK_LIVEPATCH_FORCE_STACK_LP=1 forces stack).
  CANON="${HOME}/Projects/grok-build-livepatch"
  if [[ -n "${GROK_LIVEPATCH_ROOT:-}" ]]; then
    echo "→ install-timer with GROK_LIVEPATCH_ROOT=$GROK_LIVEPATCH_ROOT"
    bash "$LP/scripts/install-timer.sh"
  elif [[ "${GROK_LIVEPATCH_KEEP_STAMP:-}" == "1" ]]; then
    echo "→ install-timer honoring preferred-install-root stamp (KEEP_STAMP=1)"
    bash "$LP/scripts/install-timer.sh"
  elif [[ "${GROK_LIVEPATCH_FORCE_STACK_LP:-}" != "1" && -x "$CANON/scripts/install-timer.sh" ]]; then
    echo "→ prefer canonical Projects livepatch: $CANON"
    GROK_LIVEPATCH_ROOT="$CANON" bash "$CANON/scripts/install-timer.sh"
  else
    echo "→ install-timer binding ROOT to stack livepatch: $LP"
    GROK_LIVEPATCH_ROOT="$LP" bash "$LP/scripts/install-timer.sh"
  fi
  # Unit ships REPLACE_BIN=1 by default; only note if disabled.
  UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/grok-build-livepatch.service"
  if [[ -f "$UNIT" ]] && grep -q 'GROK_LIVEPATCH_REPLACE_BIN=0' "$UNIT"; then
    echo "  tip: unit has REPLACE_BIN=0 (stock CLI); set =1 to activate livepatch binary"
  fi
  bash "$LP/scripts/install-timer.sh" --status || true
  echo "✓ livepatch timer enabled"
  echo "  status: bash $LP/scripts/install-timer.sh --status"
  echo "  apply:  GROK_LIVEPATCH_FORCE=1 bash \${GROK_LIVEPATCH_ROOT:-$LP}/scripts/check-and-patch.sh"
else
  echo "⚠ livepatch/ missing under stack"
fi

echo "✓ xbgst-stack host install complete"
