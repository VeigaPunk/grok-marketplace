#!/usr/bin/env bash
# Wire xbgst-stack + livepatch on this host (idempotent).
# MARKETPLACE OVERLAY — do not replace with standalone Projects-canonical logic.
#
# User overlays (skills/agents/commands/ssot) come from the installed plugin
# pin when unique. Hangar grok-marketplace / myskills copies are stealable
# dirt — they win short slashes (/user:xbgst) and load the wrong behavior.
# Never yank an installed-plugin pin onto a dirty checkout.
#
# fnm is required (fail-closed). Timer is opt-in (--install-timer).
# Livepatch ELF present → install-timer.sh --link-bin (grok-titanium), no timer.
# PATH: xbgst-mailbox + gx-teams from the pin. Set XBGST_INSTALL_GX_TEAMS=0 to skip gx-teams.
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
LOCAL_BIN="${XBGST_LOCAL_BIN:-$HOME/.local/bin}"
HANGAR_GX_TEAMS="${XBGST_HANGAR_GX_TEAMS:-}"

usage() {
  cat <<'EOF'
Usage: install-host.sh [--help|-h] [--install-timer|--rebind-timer] [--no-timer]

  --install-timer  run install-timer.sh (opt-in)
  --rebind-timer   same as --install-timer
  --no-timer       compatibility no-op (manual mode, default)

Fails closed if fnm is not on PATH. Default does not install a systemd timer.
When ~/.local/opt/grok-build-livepatch/grok exists, runs install-timer.sh --link-bin
(grok-titanium PATH) without enabling the timer.
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

if ! command -v fnm >/dev/null 2>&1; then
  echo "✗ fnm missing (install-host fail-closed)" >&2
  exit 1
fi

# Live user overlays must come from the installed plugin pin when it exists.
# Hangar/myskills copies collide with /xbgst-stack:* and win the short slash
# (/user:xbgst, /user:godspeed) — that is the wrong-behavior load.
# Never yank an installed-plugin pin onto a dirty marketplace checkout.
resolve_overlay_root() {
  local d name
  local -a matches=()
  shopt -s nullglob
  for d in "$GROK_HOME"/installed-plugins/xbgst-stack-*; do
    [[ -d "$d" && -f "$d/plugin.json" ]] || continue
    name=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name",""))' "$d/plugin.json" 2>/dev/null || true)
    if [[ "$name" == "xbgst-stack" ]]; then
      matches+=("$d")
    fi
  done
  shopt -u nullglob
  if [[ "${#matches[@]}" -gt 1 ]]; then
    echo "✗ multiple installed xbgst-stack plugins under $GROK_HOME/installed-plugins; refuse overlay" >&2
    exit 1
  fi
  if [[ "${#matches[@]}" -eq 1 ]]; then
    printf '%s' "${matches[0]}"
    return 0
  fi
  printf '%s' "$STACK_ROOT"
}

OVERLAY_ROOT="$(resolve_overlay_root)"
echo "→ overlay root: $OVERLAY_ROOT"

is_installed_pin() {
  local cur=$1
  [[ -n "$cur" ]] || return 1
  [[ "$cur" == */installed-plugins/xbgst-stack-* || "$cur" == */installed-plugins/xbgst-stack-*/ ]]
}

# Hangar dirt that used to win short names: myskills overlays, grok-marketplace
# working tree, hangar godspeed-core. Steal those onto OVERLAY_ROOT.
is_hangar_dirt() {
  local cur=$1
  [[ -n "$cur" ]] || return 1
  [[ "$cur" == */myskills/* ]] && return 0
  [[ "$cur" == */godspeed-core || "$cur" == */godspeed-core/* ]] && return 0
  [[ "$cur" == */grok-marketplace/plugins/xbgst-stack || "$cur" == */grok-marketplace/plugins/xbgst-stack/* ]] && return 0
  return 1
}

# Slash-boundary ours-test (not prefix glob).
is_ours() {
  local cur=$1
  local base=$OVERLAY_ROOT
  [[ -n "$cur" ]] || return 1
  if [[ "$cur" == "$base" || "$cur" == "$base"/* ]]; then
    return 0
  fi
  if [[ "$cur" == "$STACK_ROOT" || "$cur" == "$STACK_ROOT"/* ]]; then
    return 0
  fi
  return 1
}

retarget_ok() {
  local cur=$1
  local want=$2
  [[ -n "$cur" && -n "$want" ]] || return 1
  if is_installed_pin "$cur" && ! is_installed_pin "$want"; then
    return 1
  fi
  if is_ours "$cur" || is_hangar_dirt "$cur"; then
    return 0
  fi
  return 1
}

# Symlink one file/entry. Never clobber a real file or foreign symlink.
# Hangar/myskills stack-owned names are stealable; installed-plugin pins are not.
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
    if is_installed_pin "$cur" && ! is_installed_pin "$want"; then
      echo "→ keep plugin pin $dest" >&2
      return 0
    fi
    if retarget_ok "$cur" "$want"; then
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

# Hybrid: missing → dir symlink; our/plugin/hangar-dirt symlink → retarget;
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
    if is_installed_pin "$cur" && ! is_installed_pin "$want"; then
      echo "→ keep plugin pin $dest" >&2
      return 0
    fi
    if retarget_ok "$cur" "$want"; then
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

if [[ -d "$OVERLAY_ROOT/agents" ]]; then
  if link_stack "$GROK_HOME/agents" "$OVERLAY_ROOT/agents"; then
    echo "✓ agents → $GROK_HOME/agents (symlink)"
  fi
fi

if [[ -d "$OVERLAY_ROOT/commands" ]]; then
  if link_stack "$GROK_HOME/commands" "$OVERLAY_ROOT/commands"; then
    echo "✓ commands → $GROK_HOME/commands (symlink)"
  fi
fi

if [[ -d "$OVERLAY_ROOT/skills" ]]; then
  linked=0
  for d in "$OVERLAY_ROOT/skills"/*; do
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

if [[ -d "$OVERLAY_ROOT/ssot/godspeed-core" ]]; then
  if link_stack "$GROK_HOME/ssot/godspeed-core" "$OVERLAY_ROOT/ssot/godspeed-core"; then
    echo "✓ ssot/godspeed-core → $GROK_HOME/ssot/godspeed-core (symlink)"
  fi
fi

# Required Phase-0 names must exist after overlay when present in this stack
# (foreign skip leaves dest present — OK). Completely missing dest → fail.
missing=0
if [[ -d "$OVERLAY_ROOT/skills/godspeed" && ! -e "$GROK_HOME/skills/godspeed" ]]; then
  echo "✗ required overlay missing: $GROK_HOME/skills/godspeed" >&2
  missing=1
fi
if [[ -d "$OVERLAY_ROOT/skills/wwkd" && ! -e "$GROK_HOME/skills/wwkd" ]]; then
  echo "✗ required overlay missing: $GROK_HOME/skills/wwkd" >&2
  missing=1
fi
if [[ -d "$OVERLAY_ROOT/ssot/godspeed-core" && ! -e "$GROK_HOME/ssot/godspeed-core" ]]; then
  echo "✗ required overlay missing: $GROK_HOME/ssot/godspeed-core" >&2
  missing=1
fi
if [[ "$missing" -eq 1 ]]; then
  exit 1
fi

# PATH overlay: gx-teams + xbgst-mailbox from the pin (OVERLAY_ROOT).
# Hangar checkout is not a PATH source unless XBGST_HANGAR_GX_TEAMS is set.
GX_TEAMS_SRC="$OVERLAY_ROOT/integrations/gx-teams"
if [[ ! -x "$GX_TEAMS_SRC/gx-teams.sh" && -n "$HANGAR_GX_TEAMS" && -x "$HANGAR_GX_TEAMS/gx-teams.sh" ]]; then
  GX_TEAMS_SRC="$HANGAR_GX_TEAMS"
fi
mkdir -p "$LOCAL_BIN"
link_path_bin() {
  local dest=$1
  local src=$2
  local cur want
  want=$(readlink -f "$src" 2>/dev/null || true)
  if [[ -L "$dest" ]]; then
    cur=$(readlink -f "$dest" 2>/dev/null || true)
    if [[ -n "$cur" && -n "$want" && "$cur" == "$want" ]]; then
      ln -sfn "$src" "$dest"
      echo "✓ $(basename "$dest") → $dest"
      return 0
    fi
    if is_installed_pin "$cur" && ! is_installed_pin "$want"; then
      echo "→ keep plugin pin $dest" >&2
      return 0
    fi
    if retarget_ok "$cur" "$want"; then
      ln -sfn "$src" "$dest"
      echo "✓ $(basename "$dest") → $dest"
      return 0
    fi
    echo "⚠ skip $dest (exists, not our symlink into stack)" >&2
    return 1
  fi
  if [[ -e "$dest" ]]; then
    echo "⚠ skip $dest (exists, not a symlink)" >&2
    return 1
  fi
  ln -sfn "$src" "$dest"
  echo "✓ $(basename "$dest") → $dest"
}
if [[ "${XBGST_INSTALL_GX_TEAMS:-1}" != 0 && -x "$GX_TEAMS_SRC/gx-teams.sh" ]]; then
  link_path_bin "$LOCAL_BIN/gx-teams" "$GX_TEAMS_SRC/gx-teams.sh" || true
elif [[ "${XBGST_INSTALL_GX_TEAMS:-1}" != 0 ]]; then
  echo "⚠ gx-teams.sh missing under $GX_TEAMS_SRC" >&2
else
  echo "→ skip PATH gx-teams (XBGST_INSTALL_GX_TEAMS=0)"
fi
MAILBOX_DIR="$OVERLAY_ROOT/integrations/gx-teams/mailbox"
VENDORED_MAILBOX="$OVERLAY_ROOT/integrations/gx-teams/mailbox/Cargo.toml"
if [[ -f "$MAILBOX_DIR/Cargo.toml" ]]; then
  if [[ -x "$MAILBOX_DIR/target/release/xbgst-mailbox" ]]; then
    echo "→ skip cargo; pin mailbox ELF present"
  elif command -v cargo >/dev/null 2>&1; then
    cargo build --release --manifest-path "$MAILBOX_DIR/Cargo.toml"
  elif [[ -f "$VENDORED_MAILBOX" ]]; then
    echo "✗ cargo missing; vendored mailbox Cargo.toml requires cargo --release" >&2
    exit 1
  fi
fi
MAILBOX_BIN=""
if [[ -x "$MAILBOX_DIR/target/release/xbgst-mailbox" ]]; then
  MAILBOX_BIN="$MAILBOX_DIR/target/release/xbgst-mailbox"
elif [[ -x "$MAILBOX_DIR/target/debug/xbgst-mailbox" ]]; then
  MAILBOX_BIN="$MAILBOX_DIR/target/debug/xbgst-mailbox"
fi
if [[ -n "$MAILBOX_BIN" ]]; then
  link_path_bin "$LOCAL_BIN/xbgst-mailbox" "$MAILBOX_BIN" || true
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
  LIVE_BIN="${GROK_LIVEPATCH_INSTALL:-$HOME/.local/opt/grok-build-livepatch}/grok"
  if [[ -x "$LP/scripts/install-timer.sh" && -x "$LIVE_BIN" ]]; then
    chmod +x "$LP/scripts/install-timer.sh"
    echo "→ livepatch ELF present; --link-bin grok-titanium (no timer)"
    bash "$LP/scripts/install-timer.sh" --link-bin
  fi
else
  echo "⚠ livepatch/ missing under stack"
fi

echo "✓ xbgst-stack host install complete"
