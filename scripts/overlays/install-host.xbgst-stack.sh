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

# Slash-boundary ours-test (not prefix glob). Also treat any
# */installed-plugins/xbgst-stack-* path as ours so plugin updates retarget.
is_ours() {
  local cur=$1
  local base=$STACK_ROOT
  [[ -n "$cur" ]] || return 1
  if [[ "$cur" == "$base" || "$cur" == "$base"/* ]]; then
    return 0
  fi
  if [[ "$cur" == */installed-plugins/xbgst-stack-* ]]; then
    return 0
  fi
  return 1
}

# Symlink one file/entry. Never clobber a real file or foreign symlink.
link_one() {
  local dest=$1
  local src=$2
  local cur want
  want=$(readlink -f "$src" 2>/dev/null || true)
  if [[ -L "$dest" ]]; then
    cur=$(readlink -f "$dest" 2>/dev/null || true)
    if [[ -n "$cur" && -n "$want" && "$cur" == "$want" ]]; then
      ln -sfn "$src" "$dest"
      return 0
    fi
    if is_ours "$cur"; then
      ln -sfn "$src" "$dest"
      return 0
    fi
    echo "⚠ skip $dest (exists, not our symlink into stack)" >&2
    return 1
  fi
  if [[ -e "$dest" ]]; then
    echo "⚠ skip $dest (exists, not our symlink into stack)" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
}

# Per-entry overlay into an existing real directory (our names only).
link_into_dir() {
  local dest=$1
  local src=$2
  local item name linked=0
  for item in "$src"/*; do
    [[ -e "$item" || -L "$item" ]] || continue
    name=$(basename "$item")
    case "$name" in
      heuer-planning|the-kimiraikkoner|the-kimiraikkoner.md|xbgst-primeagent|xbgst-primeagent.md) continue ;;
    esac
    if [[ -d "$item" && ! -L "$item" ]]; then
      if link_stack "$dest/$name" "$item"; then
        linked=1
      fi
    else
      if link_one "$dest/$name" "$item"; then
        linked=1
      fi
    fi
  done
  [[ "$linked" -eq 1 ]]
}

# Hybrid: missing → dir symlink; our/plugin symlink → retarget;
# real dir → per-file of ours only; foreign symlink/file → skip.
link_stack() {
  local dest=$1
  local src=$2
  local cur want
  want=$(readlink -f "$src" 2>/dev/null || true)
  if [[ -L "$dest" ]]; then
    cur=$(readlink -f "$dest" 2>/dev/null || true)
    if [[ -n "$cur" && -n "$want" && "$cur" == "$want" ]]; then
      ln -sfn "$src" "$dest"
      return 0
    fi
    if is_ours "$cur"; then
      ln -sfn "$src" "$dest"
      return 0
    fi
    echo "⚠ skip $dest (exists, not our symlink into stack)" >&2
    return 1
  fi
  if [[ -d "$dest" ]]; then
    link_into_dir "$dest" "$src"
    return $?
  fi
  if [[ -e "$dest" ]]; then
    echo "⚠ skip $dest (exists, not our symlink into stack)" >&2
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
}

mkdir -p "$GROK_HOME" "$GROK_HOME/skills" "$GROK_HOME/ssot"

if [[ -d "$STACK_ROOT/agents" ]]; then
  if link_stack "$GROK_HOME/agents" "$STACK_ROOT/agents"; then
    echo "✓ agents → $GROK_HOME/agents (symlink)"
  fi
fi

if [[ -d "$STACK_ROOT/commands" ]]; then
  if link_stack "$GROK_HOME/commands" "$STACK_ROOT/commands"; then
    echo "✓ commands → $GROK_HOME/commands (symlink)"
  fi
fi

if [[ -d "$STACK_ROOT/skills" ]]; then
  linked=0
  for d in "$STACK_ROOT/skills"/*; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    case "$name" in
      heuer-planning|the-kimiraikkoner|xbgst-primeagent) continue ;;
    esac
    if link_stack "$GROK_HOME/skills/$name" "$d"; then
      linked=1
    fi
  done
  if [[ "$linked" -eq 1 ]]; then
    echo "✓ skills → $GROK_HOME/skills (symlinks)"
  fi
fi

if [[ -d "$STACK_ROOT/ssot/godspeed-core" ]]; then
  if link_stack "$GROK_HOME/ssot/godspeed-core" "$STACK_ROOT/ssot/godspeed-core"; then
    echo "✓ ssot/godspeed-core → $GROK_HOME/ssot/godspeed-core (symlink)"
  fi
fi

# Required Phase-0 names must exist after overlay when present in this stack
# (foreign skip leaves dest present — OK). Completely missing dest → fail.
missing=0
if [[ -d "$STACK_ROOT/skills/godspeed" && ! -e "$GROK_HOME/skills/godspeed" ]]; then
  echo "✗ required overlay missing: $GROK_HOME/skills/godspeed" >&2
  missing=1
fi
if [[ -d "$STACK_ROOT/skills/wwkd" && ! -e "$GROK_HOME/skills/wwkd" ]]; then
  echo "✗ required overlay missing: $GROK_HOME/skills/wwkd" >&2
  missing=1
fi
if [[ -d "$STACK_ROOT/ssot/godspeed-core" && ! -e "$GROK_HOME/ssot/godspeed-core" ]]; then
  echo "✗ required overlay missing: $GROK_HOME/ssot/godspeed-core" >&2
  missing=1
fi
if [[ "$missing" -eq 1 ]]; then
  exit 1
fi

if [[ -d "$LP/scripts" ]]; then
  if [[ "$INSTALL_TIMER" -eq 1 ]]; then
    chmod +x "$LP/scripts/"*.sh
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
