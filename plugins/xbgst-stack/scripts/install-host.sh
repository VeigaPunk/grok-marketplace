#!/usr/bin/env bash
# Wire xbgst-stack + livepatch on this host (idempotent).
#
# Timer root (local-first when Projects clone exists):
#   1) GROK_LIVEPATCH_ROOT if set
#   2) KEEP_STAMP=1 → honor preferred-install-root stamp
#   3) $HOME/Projects/grok-build-livepatch if install-timer exists
#   4) else this stack's livepatch/ (or FORCE_STACK_LP=1)
#
# REPLACE_BIN: unit template defaults to 1 so the active CLI gets the ban.
# Opt out: set Environment=GROK_LIVEPATCH_REPLACE_BIN=0 on the unit.
set -euo pipefail
STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LP="$STACK_ROOT/livepatch"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
CANON="${HOME}/Projects/grok-build-livepatch"

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
  if [[ -n "${GROK_LIVEPATCH_ROOT:-}" ]]; then
    echo "→ install-timer with GROK_LIVEPATCH_ROOT=$GROK_LIVEPATCH_ROOT"
    bash "${GROK_LIVEPATCH_ROOT}/scripts/install-timer.sh" 2>/dev/null \
      || bash "$LP/scripts/install-timer.sh"
  elif [[ "${GROK_LIVEPATCH_KEEP_STAMP:-}" == "1" ]]; then
    echo "→ install-timer honoring preferred-install-root stamp (KEEP_STAMP=1)"
    GROK_LIVEPATCH_KEEP_STAMP=1 bash "$LP/scripts/install-timer.sh"
  elif [[ "${GROK_LIVEPATCH_FORCE_STACK_LP:-}" != "1" && -x "$CANON/scripts/install-timer.sh" ]]; then
    echo "→ prefer canonical Projects livepatch: $CANON"
    bash "$CANON/scripts/install-timer.sh"
  else
    echo "→ install-timer binding ROOT to stack livepatch: $LP"
    bash "$LP/scripts/install-timer.sh"
  fi
  UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/grok-build-livepatch.service"
  if [[ -f "$UNIT" ]] && grep -qE '^Environment=GROK_LIVEPATCH_REPLACE_BIN=1' "$UNIT"; then
    echo "  note: unit REPLACE_BIN=1 (active CLI gets ban; set =0 on unit to opt out)"
  fi
  if [[ -x "$CANON/scripts/install-timer.sh" ]]; then
    bash "$CANON/scripts/install-timer.sh" --status || true
  else
    bash "$LP/scripts/install-timer.sh" --status || true
  fi
  echo "✓ livepatch timer enabled"
else
  echo "⚠ livepatch/ missing under stack"
fi

echo "✓ xbgst-stack host install complete"
