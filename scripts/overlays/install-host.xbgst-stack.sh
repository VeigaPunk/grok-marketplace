#!/usr/bin/env bash
# Wire xbgst-stack + livepatch on this host (idempotent).
# MARKETPLACE OVERLAY — do not replace with standalone Projects-canonical logic.
#
# Timer root (marketplace-first):
#   1) GROK_LIVEPATCH_ROOT if set
#   2) KEEP_STAMP=1 → honor preferred-install-root stamp
#   3) default → this stack's livepatch/ (GROK_LIVEPATCH_ROOT=$LP)
#
# REPLACE_BIN: unit template defaults to 1 so the active CLI gets the ban.
# Opt out: set Environment=GROK_LIVEPATCH_REPLACE_BIN=0 on the unit, or rebuild with =0.
set -euo pipefail
INSTALL_TIMER=0
STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LP="$STACK_ROOT/livepatch"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"

usage() {
  cat <<'EOF'
Usage: install-host.sh [--help|-h] [--install-timer|--rebind-timer] [--no-timer]

  --install-timer  run install-timer.sh (opt-in)
  --rebind-timer   same as --install-timer
  --no-timer       compatibility no-op (manual mode, default)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage; exit 0 ;;
    --install-timer|--rebind-timer) INSTALL_TIMER=1 ;;
    --no-timer) : ;; # compatibility no-op; manual mode is already the default
    --*) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
    *) echo "Unexpected positional arg: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

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
  if [[ "$INSTALL_TIMER" -eq 1 ]]; then
    if [[ -n "${GROK_LIVEPATCH_ROOT:-}" ]]; then
      echo "→ install-timer with GROK_LIVEPATCH_ROOT=$GROK_LIVEPATCH_ROOT"
      bash "$LP/scripts/install-timer.sh"
    elif [[ "${GROK_LIVEPATCH_KEEP_STAMP:-}" == "1" ]]; then
      echo "→ install-timer honoring preferred-install-root stamp (KEEP_STAMP=1)"
      GROK_LIVEPATCH_KEEP_STAMP=1 bash "$LP/scripts/install-timer.sh"
    else
      echo "→ install-timer binding ROOT to stack livepatch: $LP"
      GROK_LIVEPATCH_ROOT="$LP" bash "$LP/scripts/install-timer.sh"
    fi
    UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/grok-build-livepatch.service"
    if [[ -f "$UNIT" ]] && grep -qE '^Environment=GROK_LIVEPATCH_REPLACE_BIN=1' "$UNIT"; then
      echo "  note: unit REPLACE_BIN=1 (active CLI gets ban; set =0 on unit to opt out)"
    fi
    bash "$LP/scripts/install-timer.sh" --status || true
    echo "✓ livepatch timer enabled (stack LP=$LP)"
    echo "  apply: GROK_LIVEPATCH_FORCE=1 bash ${GROK_LIVEPATCH_ROOT:-$LP}/scripts/check-and-patch.sh"
    echo "  link:  bash $LP/scripts/install-timer.sh --link-bin"
  else
    echo "→ timer changes skipped (manual mode default). use --install-timer to opt in"
  fi
else
  echo "⚠ livepatch/ missing under stack"
fi

echo "✓ xbgst-stack host install complete"
